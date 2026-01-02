#!/bin/bash
apt install pv

# -------------------------------
# Script interactif / non interactif + log
# -------------------------------

# Couleurs
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RED="\033[1;31m"
NC="\033[0m"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="$SCRIPT_DIR/create_lab_$(date +%Y%m%d_%H%M%S).log"

# Redirige stdout et stderr vers log
exec > >(tee -a "$LOGFILE") 2>&1

echo -e "${GREEN}===== Démarrage du script =====${NC}"
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

    >&2 echo -e "${GREEN}Extraction de '$ova_path' vers '$target_dir/'...${NC}"
    mkdir -p "$target_dir"
    pv "$ova_path" | tar -x -C "$target_dir" >&2
    >&2 echo -e "${GREEN}Extraction terminée pour '$ova_path' → '$target_dir/'${NC}"

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
    local MODE="$4"           # interactive / auto
    local CREATED_VMS_REF="$5"
    local EXISTING_VMS_REF="$6"
    local SKIPPED_OWNS_REF="$7"

    local ID_VM=$((lab*100+num_vm))
    local vmdk_file=$(ls *.vmdk | head -n1)
    local VM_NAME="lab${lab}-vm${num_vm}"

    # Vérifier si VMID existe déjà
    if qm list | awk 'NR>1 {print $1}' | grep -q "^$ID_VM\$"; then
        >&2 echo "VMID $ID_VM déjà existant pour $VM_NAME !"
        eval "$EXISTING_VMS_REF+=(\"$VM_NAME\")"
        if [ "$MODE" == "interactive" ]; then
            while true; do
                read -p "Voulez-vous continuer malgré la VM existante pour $VM_NAME ? (oui/non) " rep
                case "$rep" in
                    oui|OUI|o|y|yes)
                        echo "→ Création forcée"
                        break
                        ;;
                    non|NON|n|no)
                        echo "Opération annulée pour $VM_NAME"
                        eval "$SKIPPED_OWNS_REF+=(\"$VM_NAME\")"
                        return
                        ;;
                    *)
                        echo "Réponse invalide (oui/non)"
                        ;;
                esac
            done
        else
            echo "Mode auto : VM existante ignorée"
            eval "$SKIPPED_OWNS_REF+=(\"$VM_NAME\")"
            return
        fi
        # Trouver NUM_VM libre
        num_vm=$(get_next_available_num_vm "$lab" 1)
        ID_VM=$((lab*100+num_vm))
        #local VM_NAME="lab${lab}-vm${num_vm}"
        local VM_NAME="lab${lab}-$base_name"
        echo "Nouvel ID_VM utilisé : $ID_VM"
    fi

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

MODE="interactive"   # par défaut interactif
NUM_LAB=""
NUM_VM=""
OVA_DIR=""

# Parsing arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --interactive)
            MODE="interactive"
            shift
            ;;
        --non-interactive)
            MODE="auto"
            shift
            ;;
        --lab)
            NUM_LAB="$2"
            shift 2
            ;;
        --start-vm)
            NUM_VM="$2"
            shift 2
            ;;
        --ova-dir)
            OVA_DIR="$2"
            shift 2
            ;;
        *)
            echo "Argument inconnu : $1"
            exit 1
            ;;
    esac
done

# Si interactif, demander si pas fourni
if [ "$MODE" == "interactive" ]; then
    [ -z "$NUM_LAB" ] && read -p "Valeur de NUM_LAB ? " NUM_LAB
    [ -z "$NUM_VM" ] && read -p "NUM_VM de départ ? " NUM_VM
    [ -z "$OVA_DIR" ] && read -p "Dossier contenant les fichiers OVA (laisser vide = courant) : " OVA_DIR
else
    # Mode auto
    [ -z "$NUM_LAB" ] || [ -z "$NUM_VM" ] && { echo "Usage auto : --non-interactive --lab NUM_LAB --start-vm NUM_VM [--ova-dir DIR]"; exit 1; }
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

NUM_VM="$NUM_VM"

# -------------------------------
# Boucle sur les OVA
# -------------------------------
for ova_file in "${OVA_FILES[@]}"; do
    read base_name target_dir < <(extract_ova "$ova_file")
    [ -z "$base_name" ] && { echo "Extraction ignorée pour $ova_file"; SKIPPED_OWNS+=("$ova_file"); continue; }

    cd "$target_dir" || { echo "Impossible de se placer dans $target_dir"; SKIPPED_OWNS+=("$base_name"); continue; }

    NUM_VM_AVAILABLE=$(get_next_available_num_vm "$NUM_LAB" "$NUM_VM")
    create_vm "$base_name" "$NUM_LAB" "$NUM_VM_AVAILABLE" "$MODE" CREATED_VMS EXISTING_VMS SKIPPED_OWNS

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

