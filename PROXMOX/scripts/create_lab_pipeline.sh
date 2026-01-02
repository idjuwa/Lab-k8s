#!/bin/bash
apt install pv

# -------------------------------
# Script non interactif avec log
# -------------------------------

# Couleurs
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/create_lab_non_interactive_$(date +%Y%m%d_%H%M%S).log"

# Redirige stdout et stderr vers le log
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${GREEN}===== Démarrage du script non interactif =====${NC}"
echo "Script lancé depuis : $SCRIPT_DIR"
echo "Log enregistré dans : $LOGFILE"

# -------------------------------
# Fonctions
# -------------------------------

extract_ova() {
    local ova_path="$1"
    [ -f "$ova_path" ] || { return; }

    local base_name="$(basename "$ova_path" .ova)"
    local target_dir="$SCRIPT_DIR/$base_name"

    [ -d "$target_dir" ] && { return; }

    # Messages sur stderr
    >&2 echo -e "${GREEN}Extraction de '$ova_path' vers '$target_dir/'...${NC}"
    mkdir -p "$target_dir"
    pv "$ova_path" | tar -x -C "$target_dir" >&2
    >&2 echo -e "${GREEN}Extraction terminée pour '$ova_path' → '$target_dir/'${NC}"

    # Valeurs pour read
    echo "$base_name" "$target_dir"
}

get_next_available_num_vm() {
    local lab="$1"
    local start_num="$2"
    local used_vmids=($(qm list | awk 'NR>1 {print $1}'))
    local num="$start_num"

    while true; do
        local id_vm=$((lab*100+num))
        if [[ ! " ${used_vmids[@]} " =~ " $id_vm " ]]; then
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
    local vmdk_file=$(ls *.vmdk | head -n1)

    # Nom de la VM
    #local VM_NAME="lab${lab}-vm${num_vm}"
    local VM_NAME="lab${lab}-$base_name"

    # Vérifier si VMID existe
    if qm list | awk 'NR>1 {print $1}' | grep -q "^$ID_VM\$"; then
        >&2 echo "VMID $ID_VM déjà existant pour $VM_NAME ! Ignorée."
        eval "$EXISTING_VMS_REF+=(\"$VM_NAME\")"
        return
    fi

    # Conversion et création VM
    echo -e "${GREEN}Création de la VM $VM_NAME (ID $ID_VM)...${NC}"
    # qemu-img convert -p -f vmdk "$vmdk_file" -O qcow2 "$base_name.qcow2"
    qemu-img convert -p -f vmdk "$vmdk_file" -O qcow2 "$base_name.qcow2" 2>&1 \
| sed -u 's/.*(\(transferred.*\))/\r\1/' && echo
    qm create $ID_VM --name "$VM_NAME" --memory 4096 --cores 4 --net0 virtio,bridge=vmbr0
    # qm importdisk $ID_VM "$base_name.qcow2" local-lvm
    qm importdisk "$ID_VM" "$base_name.qcow2" local-lvm 2>&1 \
| sed -u 's/.*\(transferred.*\)/\r\1/' && echo
    qm set $ID_VM --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-$ID_VM-disk-0

    eval "$CREATED_VMS_REF+=(\"$VM_NAME\")"
}

# -------------------------------
# Paramètres
# -------------------------------
NUM_LAB="$1"
NUM_VM_START="$2"
OVA_DIR="$3"

if [ -z "$NUM_LAB" ] || [ -z "$NUM_VM_START" ]; then
    echo -e "${RED}Usage : $0 NUM_LAB NUM_VM_START [OVA_DIR]${NC}"
    exit 1
fi

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

NUM_VM="$NUM_VM_START"

# -------------------------------
# Boucle sur les OVA
# -------------------------------
for ova_file in "${OVA_FILES[@]}"; do
    read base_name target_dir < <(extract_ova "$ova_file")
    [ -z "$base_name" ] && { echo "Extraction ignorée pour $ova_file"; SKIPPED_OWNS+=("$ova_file"); continue; }

    cd "$target_dir" || { echo "Impossible de se placer dans $target_dir"; SKIPPED_OWNS+=("$base_name"); continue; }

    NUM_VM_AVAILABLE=$(get_next_available_num_vm "$NUM_LAB" "$NUM_VM")
    create_vm "$base_name" "$NUM_LAB" "$NUM_VM_AVAILABLE" CREATED_VMS EXISTING_VMS SKIPPED_OWNS

    NUM_VM=$((NUM_VM_AVAILABLE+1))
    cd "$SCRIPT_DIR" || exit
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

echo -e "${RED}VM existantes non créées :${NC}"
for vm in "${EXISTING_VMS[@]}"; do
    echo "  - $vm"
done
echo -e "${GREEN}=========================${NC}"

