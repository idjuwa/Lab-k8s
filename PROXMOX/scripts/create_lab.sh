#!/bin/bash

apt install -y pv

# Couleurs
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------------------------------
# Fonctions
# -------------------------------

extract_ova() {
    local ova_path="$1"
    [ -f "$ova_path" ] || return

    local base_name
    base_name="$(basename "$ova_path" .ova)"
    local target_dir="$SCRIPT_DIR/$base_name"

    [ -d "$target_dir" ] && return

    >&2 echo -e "${GREEN}Extraction de '$ova_path' vers '$target_dir/'...${NC}"
    mkdir -p "$target_dir"
    pv "$ova_path" | tar -x -C "$target_dir" >&2
    >&2 echo -e "${GREEN}Extraction terminée pour '$ova_path' → '$target_dir/'${NC}"

    printf "%s %s\n" "$base_name" "$target_dir"
}

get_next_available_num_vm() {
    local lab="$1"
    local start_num="$2"
    local used_vmids
    mapfile -t used_vmids < <(qm list | awk 'NR>1 {print $1}')

    local num="$start_num"
    local id_vm

    while true; do
        id_vm=$((lab*100+num))
        if [[ ! " ${used_vmids[*]} " =~ " $id_vm " ]]; then
            echo "$num"
            return
        fi
        num=$((num+1))
    done
}

create_vm() {
    local base_name="$1"
    local lab="$2"
    local num_vm="$3"
    local CREATED_VMS_REF="$4"
    local EXISTING_VMS_REF="$5"
    local SKIPPED_OWNS_REF="$6"

    local ID_VM=$((lab*100+num_vm))
    local VM_NAME="lab${lab}-${base_name}"

    local vmdk_file
    vmdk_file=$(ls *.vmdk 2>/dev/null | head -n1)

    if [ -z "$vmdk_file" ]; then
        echo -e "${RED}Aucun fichier .vmdk trouvé pour $base_name${NC}"
        eval "$SKIPPED_OWNS_REF+=(\"$base_name\")"
        return
    fi

    if qm list | awk 'NR>1 {print $1}' | grep -q "^$ID_VM$"; then
        echo -e "${YELLOW}VMID $ID_VM déjà existant → ignorée${NC}"
        eval "$EXISTING_VMS_REF+=(\"$base_name\")"
        eval "$SKIPPED_OWNS_REF+=(\"$base_name\")"
        return
    fi

    echo -e "${GREEN}Création de la VM $VM_NAME (ID $ID_VM)...${NC}"

    qemu-img convert -p -f vmdk "$vmdk_file" -O qcow2 "$base_name.qcow2" 2>&1 \
    | sed -u 's/.*(\(transferred.*\))/\r\1/' && echo

    qm create "$ID_VM" \
        --name "$VM_NAME" \
        --memory 4096 \
        --cores 4 \
        --net0 virtio,bridge=vmbr0

    # qm importdisk "$ID_VM" "$base_name.qcow2" local-lvm
    qm importdisk "$ID_VM" "$base_name.qcow2" local-lvm 2>&1 \
| sed -u 's/.*\(transferred.*\)/\r\1/' && echo
    qm set "$ID_VM" --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-"$ID_VM"-disk-0

    eval "$CREATED_VMS_REF+=(\"$VM_NAME\")"
}

# -------------------------------
# Script principal
# -------------------------------

read -p "Valeur de NUM_LAB ? " NUM_LAB
read -p "NUM_VM de départ ? " NUM_VM
read -p "Dossier contenant les fichiers OVA (laisser vide = courant) : " OVA_DIR
[ -z "$OVA_DIR" ] && OVA_DIR="$SCRIPT_DIR"

CREATED_VMS=()
EXISTING_VMS=()
SKIPPED_OWNS=()

shopt -s nullglob
OVA_FILES=("$OVA_DIR"/*.ova)
shopt -u nullglob

if [ ${#OVA_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}Aucun fichier .ova trouvé dans '$OVA_DIR'.${NC}"
    exit 0
fi

# -------------------------------
# Boucle principale
# -------------------------------

for ova_file in "${OVA_FILES[@]}"; do
    read base_name target_dir < <(extract_ova "$ova_file")

    if [ -z "$base_name" ] || [ -z "$target_dir" ]; then
        echo -e "${YELLOW}Extraction ignorée pour $ova_file${NC}"
        SKIPPED_OWNS+=("$(basename "$ova_file")")
        continue
    fi

    cd "$target_dir" || {
        echo -e "${RED}Impossible de se placer dans $target_dir${NC}"
        SKIPPED_OWNS+=("$base_name")
        continue
    }

    NUM_VM_AVAILABLE=$(get_next_available_num_vm "$NUM_LAB" "$NUM_VM")
    create_vm "$base_name" "$NUM_LAB" "$NUM_VM_AVAILABLE" CREATED_VMS EXISTING_VMS SKIPPED_OWNS

    NUM_VM=$((NUM_VM_AVAILABLE+1))
    cd "$SCRIPT_DIR" || exit 1
done

# -------------------------------
# Rapport final
# -------------------------------

echo -e "\n${GREEN}===== Rapport final =====${NC}"

echo -e "${GREEN}VM créées :${NC}"
for vm in "${CREATED_VMS[@]}"; do
    echo "  - $vm"
done

echo -e "${YELLOW}VM ignorées :${NC}"
for vm in "${SKIPPED_OWNS[@]}"; do
    echo "  - $vm"
done

echo -e "${RED}VM existantes :${NC}"
for vm in "${EXISTING_VMS[@]}"; do
    echo "  - $vm"
done

echo -e "${GREEN}=========================${NC}"
