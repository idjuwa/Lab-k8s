#########################################################################
# Création de lab à partir d'un dossier contenant les ova interactif v1 #
#########################################################################
# Valeur de NUM_LAB ? 3
# NUM_VM de départ ? 1
# Dossier contenant les fichiers OVA (laisser vide = courant) :
./create_lab.sh

Exemple :
./create_lab.sh
./create_lab.sh
# Réponses :
# Valeur de NUM_LAB ? 3
# NUM_VM de départ ? 1
# Dossier contenant les fichiers OVA (laisser vide = courant) :
# Extraction et création avec barre de progression
# Confirmation si VM existe déjà
Ignore si ID_VM existe et passe à la VM suivante.
Log:
# Le script crée automatiquement un fichier log avec timestamp :
create_lab_20251224_153015.log
Rapport final
Interactif :

#############################################################################
# Création de lab à partir d'un dossier contenant les ova non interactif v1 #
#############################################################################
./create_lab_pipeline-ready.sh NUM_LAB NUM_VM_DEPART DOSSIER_OVA
Exemple:
./create_lab_pipeline-ready.sh 3 1 /mnt/pve/pve1_usb/Lab-k8s/Loadbalancer
 3 → numéro du lab
 1 → premier numéro de VM à utiliser pour ce lab
 /mnt/pve/pve1_usb/Lab-k8s/Loadbalancer → dossier contenant les fichiers .ova à traiter
Le script ne posera aucune question.
Ignore si ID_VM existe et passe à la VM suivante.
Log:
# Le script crée automatiquement un fichier log avec timestamp :
create_lab_20251224_153015.log
Rapport final
Interactif :

#########################################################################
# Création de lab à partir d'un dossier contenant les ova interactif v2 #
#########################################################################
########### Mode interactif version2 (create_lab-v2.sh) #################
Dossier initial
/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/
├── lb1.ova
├── lb2.ova
├── lb3.ova

Lancement du script (mode interactif)
./create_lab-v2.sh

Valeur de NUM_LAB ? 3
NUM_VM de départ ? 1
Dossier contenant les fichiers OVA (laisser vide = courant) :

Extraction et conversion
Extraction de 'lb1.ova' vers '/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/lb1/'...
[==============>                  ] 40%  100MB/s
Extraction terminée pour 'lb1.ova' → '/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/lb1/'

Conversion de 'lb1-disk001.vmdk' → 'lb1.qcow2'...
[====>                          ] 25%  50MB/s
Conversion terminée
Même flux pour lb2.ova et lb3.ova.
Vérification VM existantes

Si VMID 303 existe pour lb3 :

VMID 303 déjà existant pour lb3
Voulez-vous continuer malgré la VM existante pour lab3-vm3 ? (oui/non) oui
→ Création forcée avec le prochain ID_VM libre : 304

Création des VMs sur Proxmox
OVA	VMID	Nom VM
lb1.ova	301	lab3-vm1
lb2.ova	302	lab3-vm2
lb3.ova	304	lab3-vm3

Disque QCOW2 importé, RAM 4Go, CPU 4, réseau virtio.

Rapport final affiché
===== Rapport final =====
VM créées :
  - lab3-vm1
  - lab3-vm2
  - lab3-vm3
VM ignorées :
  - (aucune)
VM existantes non créées :
  - (aucune)
=========================

Log:
Fichier généré :
create_lab_20251224_154500.log

Extraction de 'lb1.ova' vers '/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/lb1/' ... [NC]
...
Conversion de 'lb1-disk001.vmdk' → 'lb1.qcow2' ... [NC]
...
VM lab3-vm1 créée (ID_VM 301) [NC]
...
VMID 303 existante pour lb3, confirmation utilisateur : oui [NC]
Création forcée : lab3-vm3 (ID_VM 304) [NC]
...
===== Rapport final ===== [NC]
VM créées :
  - lab3-vm1
  - lab3-vm2
  - lab3-vm3
VM ignorées :
VM existantes non créées :
=========================

#############################################################################
# Création de lab à partir d'un dossier contenant les ova non interactif v2 #
#############################################################################
# Mode interactif :
./create_lab-v2.sh interactive
# Mode automatique (CI/CD) :
# 3 : NUM_LAB
# 1 : NUM_VM de départ
# /mnt/pve/pve1_usb/Lab-k8s/Loadbalancer → dossier contenant les .ova
./script.sh auto NUM_LAB NUM_VM REP
Exemple: 
./script.sh auto 3 1 /mnt/pve/pve1_usb/Lab-k8s/Loadbalancer
###################### Mode non interactif v2 ###############################
Dossier initial
/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/
├── lb1.ova
├── lb2.ova
├── lb3.ova

Lancement du script (mode non interactif)
./create_lab-v2.sh --non-interactive --lab 3 --start-vm 1 --ova-dir /mnt/pve/pve1_usb/Lab-k8s/Loadbalancer
--lab 3 → numéro du lab
--start-vm 1 → premier numéro de VM à utiliser
--ova-dir ... → chemin des fichiers .ova

Comportement :
NUM_VM commence à 1 et est incrémenté automatiquement.
Si un ID_VM existe déjà, il est ignoré et le script passe au prochain ID_VM libre.

Extraction et conversion:
Extraction de 'lb1.ova' vers '/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/lb1/'...
[==============>                  ] 40%  100MB/s
Extraction terminée

Conversion de 'lb1-disk001.vmdk' → 'lb1.qcow2'...
[====>                          ] 25%  50MB/s
Conversion terminée

Même flux pour lb2.ova et lb3.ova.
Gestion automatique des VM existantes
Si ID_VM = 303 (pour lb3) existe:
VMID 303 existante pour lb3, mode non interactif → ignorée
NUM_VM est automatiquement ajusté au prochain ID_VM libre (ici 304).

Création des VMs sur Proxmox
OVA	VMID	Nom VM
lb1.ova	301	lab3-vm1
lb2.ova	302	lab3-vm2
lb3.ova	304	lab3-vm3

Disque QCOW2 importé, RAM 4Go, CPU 4, réseau virtio.

Rapport final affiché
===== Rapport final =====
VM créées :
  - lab3-vm1
  - lab3-vm2
  - lab3-vm3
VM ignorées :
  - lb3.ova   <-- si ID_VM existait initialement
VM existantes non créées :
  - lb3     <-- VMID initialement existante
=========================
Log:
Fichier généré :
create_lab_20251224_160500.log
Contenu simulé :
Extraction de 'lb1.ova' vers '/mnt/pve/pve1_usb/Lab-k8s/Loadbalancer/lb1/' [NC]
...
Conversion de 'lb1-disk001.vmdk' → 'lb1.qcow2' [NC]
...
VM lab3-vm1 créée (ID_VM 301) [NC]
...
VMID 303 existante pour lb3, ignorée en mode non interactif [NC]
...
===== Rapport final ===== [NC]
VM créées :
  - lab3-vm1
  - lab3-vm2
  - lab3-vm3
VM ignorées :
  - lb3.ova
VM existantes non créées :
  - lb3
=========================

NOM VM = lab<NUM_LAB>-vm<NUM_VM>
NUM_VM incrémenté automatiquement
Log avec timestamp

###############################################################

+----------------------------+-------------------------------------------------------+-------------------------------+-----------------------------------------------------------------------------------+
| Option / Paramètre         | Description                                           | Mode d’utilisation            | Remarques                                                                         |
+----------------------------+-------------------------------------------------------+-------------------------------+-----------------------------------------------------------------------------------+
| --interactive              | Active le mode interactif (questions à l’utilisateur) | Par défaut si non précisé     | Pose des questions pour NUM_LAB, NUM_VM, dossier OVA et confirmation VM existante |
| --non-interactive / --auto | Mode automatique, aucune question                     | Non interactif                | Les VM existantes sont ignorées, le script utilise le prochain NUM_VM disponible  |
| --lab NUM_LAB              | Numéro du lab                                         | Obligatoire en non interactif | Calcul de VMID et nom VM (labY-vmX)                                               |
| --start-vm NUM_VM          | Numéro de départ de la première VM dans le lab        | Obligatoire en non interactif | Incrémente automatiquement pour VM suivantes                                      |
| --ova-dir CHEMIN           | Répertoire contenant les fichiers .ova                | Optionnel                     | Par défaut = répertoire du script (SCRIPT_DIR)                                    |
| NUM_LAB (interactif)       | Valeur du lab demandée via prompt                     | Interactif                    | Remplace --lab en mode interactif                                                 |
| NUM_VM (interactif)        | Numéro de VM de départ via prompt                     | Interactif                    | Remplace --start-vm en mode interactif                                            |
| Dossier OVA (interactif)   | Répertoire des fichiers .ova via prompt               | Interactif                    | Laisser vide = répertoire du script                                               |
| Log                        | Fichier log généré automatiquement                    | Tous modes                    | Nom = create_lab_<YYYYMMDD_HHMMSS>.log, stdout + stderr                           |
| Nom des VMs                | Format des VMs créées                                 | Tous modes                    | labY-vmX, Y = NUM_LAB, X = numéro de VM                                           |
| Gestion VM existante       | Comportement si VMID déjà existant                    | Interactif / Non interactif   | Interactif → demande confirmation, Non interactif → ignore VM                     |
+----------------------------+-------------------------------------------------------+-------------------------------+-----------------------------------------------------------------------------------+

######### Workflow ##############

┌────────────────────────────────┐
│ Dossier contenant les fichiers │
│ .ova (lb1.ova, lb2.ova, ...)   │
└───────────────┬────────────────┘
                │
                ▼
      ┌─────────────────────┐
      │ Extraction OVA      │
      │ tar -xvf / barre pv │
      └─────────┬───────────┘
                │
                ▼
    ┌───────────────────────────┐
    │ Dossier créé par OVA      │
    │ lb1/, lb2/, ...           │
    │ Contient .ovf + .vmdk     │
    └───────────┬───────────────┘
                │
                ▼
    ┌─────────────────────────┐
    │ Conversion VMDK → QCOW2 │
    │ qemu-img -p             │
    │ lb1.qcow2, lb2.qcow2,...│
    └───────────┬─────────────┘
                │
                ▼
       ┌───────────────────────────┐
       │ Création VM Proxmox       │
       │ VMID = NUM_LAB*100+NUM_VM │
       │ Nom = labY-vmX            │
       │ RAM=4Go, CPU=4            │
       │ Disque attaché            │
       │ Réseau virtio             │
       └─────────┬─────────────────┘
                 │
                 ▼
      ┌───────────────────────────────────────────────┐
      │ Vérification VMID existant                    │
      ├────────────────────────────┬─────────┬────────┘
      │ Existe ?                   │ Oui     │ Non
      │                            │         │
      ▼                            │         ▼
Mode interactif                    │  Création VM normale
- Demande confirmation             │
    - "Voulez-vous continuer ?"    │
      │                            ▼
      │    - Oui → crée VM avec NUM_VM libre
      │    - Non → ignore VM
      │
Mode non interactif
- Ignore automatiquement et passe au suivant
      │
      ▼
 ┌──────────────────────────────────────────┐
 │ Rapport final & log                      │
 │ VM créées : lab3-vm1,...                 │
 │ VM ignorées : lb3.ova                    │
 │ VM existantes non créées                 │
 │ Log complet : create_lab_<timestamp>.log │
 └──────────────────────────────────────────┘
