#!/usr/bin/env bash

###############################################################################################
# Usage : chmod +x deploy.sh && sudo ./deploy.sh                                              #
# Pour passer le clavier en français avant de lancer le script :                              #
# gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'fr')]" && sudo ./deploy.sh #
###############################################################################################

###############################################################################################
#  CONTEXTE D'EXECUTION                                                                       #
###############################################################################################
set -euo pipefail

# Vérification des droits
if [[ $EUID -ne 0 ]]; then
    echo "Ce script doit être lancé avec sudo : sudo ./deploy.sh"
    exit 1
fi

# On détecte si on est sur un live d'installation (squashfs) ou un système déjà installé.
# La logique d'éxecution adaptée au cas de figure sera lancée.
if findmnt -t squashfs -no SOURCE | grep -q .; then
    TARGET_MOUNT="/mnt"
    echo "Live ISO, installation"
else
    TARGET_MOUNT=""
    echo "Système installé, rebuild"
fi

CONFIG_FILE="${TARGET_MOUNT}/etc/nixos/configuration.nix"

###############################################################################################
#  LOGIQUE D'EXECUTION                                                                        #
###############################################################################################
executer_installation() {
    echo "══════════════════════════════════════════"
    echo "  Deploiement par installation"
    echo "══════════════════════════════════════════"
    initialiser_environnement_installation
    configurer_disque
    if cryptsetup isLuks "$PART_LUKS" 2>/dev/null; then
        supprimer_volumes_OS
    else
        supprimer_tout_volume
    fi
    structurer_nouveaux_volumes
    definir_infos_initiales
    generer_infos_inexistantes # à épurer
    telecharger_repo_git
    preparer_configuration.nix
    renseigner_configuration.nix
    generer_variables.nix
    installer_Nixos
    migrer_fichiers_persistants
    finaliser
}

executer_rebuild() {
    echo "══════════════════════════════════════════"
    echo "  Deploiement par rebuild"
    echo "══════════════════════════════════════════"
    collecter_infos_existantes
    generer_infos_inexistantes
    telecharger_repo_git
    sauvegarder_configuration.nix
    renseigner_configuration.nix
    generer_variables.nix
    rebuilder_Nixos
    migrer_fichiers_persistants
    finaliser
}

###############################################################################################
#  FONCTIONS                                                                                  #
###############################################################################################

initialiser_environnement_installation() {
    echo "══════════════════════════════════════════"
    echo "  Initialisation de l'environnement"
    echo "══════════════════════════════════════════"

    timedatectl set-timezone Europe/Paris

    read -rp "Configurer le wifi ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 0; }
    echo "Réseaux WiFi disponibles :"
    nmcli device wifi list
    read -rp "SSID du réseau : " WIFI_SSID
    read -rsp "Mot de passe WiFi : " WIFI_PASSWORD
    echo "Connexion à '$WIFI_SSID'..."
    nmcli device wifi connect "$WIFI_SSID" password "$WIFI_PASSWORD"
    unset WIFI_PASSWORD
    echo "Attente de la connexion réseau..."
    until ping -c1 github.com &>/dev/null; do
        sleep 2
    done
    echo "✓ Connexion établie."
}

configurer_disque() {
    echo "══════════════════════════════════════════"
    echo "  Configuration du disque"
    echo "══════════════════════════════════════════"
    read -rp "Configurer le disque ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 0; }

    # Selection du disque
    echo "Disques disponibles :"
    lsblk -d -o NAME,SIZE,MODEL
    read -rp "Entrez le disque cible (ex: sda, nvme0n1) : " DISK
    DISK="/dev/${DISK#/dev/}"

    # Noms des partitions selon type de disque (nvme ou sata)
    if [[ "$DISK" == *nvme* ]]; then
        PART_BOOT="${DISK}p1"
        PART_LUKS="${DISK}p2"
    else
        PART_BOOT="${DISK}1"
        PART_LUKS="${DISK}2"
    fi

    # Préparation
    OPTS="noatime,compress=zstd,space_cache=v2,ssd,discard=async"
    ROOT_SUBVOLUME="root"
    ROOT_SNAPSHOT="$ROOT_SUBVOLUME-blank"
    TMP_MOUNT=$(mktemp -d)
    mkdir -p "$TMP_MOUNT"
}

supprimer_volumes_OS () {
    echo "══════════════════════════════════════════"
    echo "  LUKS détecté sur $DISK. Suppression des "
    echo "  partitions et volumes système uniquement"
    echo "══════════════════════════════════════════"
    read -rp "Confirmer ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 1; }

    # effacer la partition boot
    wipefs --all --force "$PART_BOOT"
    partprobe "$DISK"
    udevadm settle

    # effacer, dans le conteneur LUKS, tout autre sous-volume que home / cargo
    LUKS_UUID=$(cryptsetup luksUUID "$PART_LUKS")
    LUKS_NAME="luks-${LUKS_UUID}"
    cryptsetup open "$PART_LUKS" "$LUKS_NAME"
    mount -o subvolid=5 "/dev/mapper/$LUKS_NAME" "$TMP_MOUNT"
    for sv in "$TMP_MOUNT"/*; do
      [ -e "$sv" ] || continue
      base_sv=$(basename "$sv") # cf explication gemini "Script Bash : Initialisation/Réinstallation LUKS"
      [[ "$base_sv" =~ ^(home|cargo)$ ]] || btrfs subvolume delete -R -c "$sv" 2>/dev/null || rm -rf "$sv"
    done
}

supprimer_tout_volume () {
    echo "══════════════════════════════════════════"
    echo "  Aucun LUKS sur $DISK : contexte risqué. "
    echo "  -> effacement intérgal du disque        "
    echo "══════════════════════════════════════════"
    read -rp "Confirmer ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 1; }

    # effacer intégralement le disque puis recréer les partitions (
    wipefs --all --force "$DISK"
    sgdisk --zap-all "$DISK"
    sgdisk --new=1:0:+1024M --typecode=1:ef00 "$DISK"
    sgdisk --new=2:0:0      --typecode=2:8309 "$DISK"
    partprobe "$DISK"
    udevadm settle
        
    # créer le conteneur LUKS et le volume BTRFS
    cryptsetup luksFormat --type luks2 "$PART_LUKS"
    LUKS_UUID=$(cryptsetup luksUUID "$PART_LUKS")
    LUKS_NAME="luks-${LUKS_UUID}"
    cryptsetup open "$PART_LUKS" "$LUKS_NAME"
    mkfs.btrfs -f -L nixos "/dev/mapper/$LUKS_NAME"
        
    # Montage initial pour la création des sous-volumes
    mount -o subvolid=5 "/dev/mapper/$LUKS_NAME" "$TMP_MOUNT"
}

structurer_nouveaux_volumes () {
    echo "══════════════════════════════════════════"
    echo " Mise en place et des nouveaux volumes : "
    echo " ├─ partition boot (standard Calamares)   "
    echo " └─ partition LUKS (standard Calamares)   "
    echo "  └─ volume BTRFS (standard Calamares)    "
    echo "   ├── $ROOT_SUBVOLUME (pour impermanence)"
    echo "   ├── $ROOT_SNAPSHOT (pour impermanence) "
    echo "   ├── nix (standard Calamares)           "
    echo "   └── home (standard Calamares)          "
    echo "══════════════════════════════════════════"
    mkfs.fat -F32 -n BOOT "$PART_BOOT"
    btrfs subvolume create "$TMP_MOUNT/$ROOT_SUBVOLUME"
    btrfs subvolume create "$TMP_MOUNT/nix"
    btrfs subvolume create "$TMP_MOUNT/home" 2>/dev/null || true # Ignoré si préservé
    btrfs subvolume snapshot -r "$TMP_MOUNT/$ROOT_SUBVOLUME" "$TMP_MOUNT/$ROOT_SNAPSHOT" # Snapshot vierge en lecture seule
    
    umount "$TMP_MOUNT"
    rmdir "$TMP_MOUNT"

    # Montage final pour NixOS
    mount -o "$OPTS,subvol=$ROOT_SUBVOLUME" "/dev/mapper/$LUKS_NAME" /mnt
    mkdir -p /mnt/{boot,nix,home}    
    mount "$PART_BOOT" /mnt/boot -o umask=0077
    mount -o "$OPTS,subvol=nix"   "/dev/mapper/$LUKS_NAME" /mnt/nix
    mount -o "$OPTS,subvol=home"  "/dev/mapper/$LUKS_NAME" /mnt/home
    echo "✓ Terminé. Disque prêt pour l'installation."
    findmnt -R /mnt
}

definir_infos_initiales () {
    echo "══════════════════════════════════════════"
    echo "  Définitions des informations initiales  "
    echo "  Compilation pour variables.nix          "
    echo "══════════════════════════════════════════"
    MACHINE_ID=$(systemd-id128 new | tr -d '-')
    NIXOS_VERSION=$(nixos-version | cut -d. -f1,2)
    if [[ -z "$NIXOS_VERSION" ]]; then
        echo "Impossible de détecter la version NixOS automatiquement."
        read -rp "Entre-la manuellement (ex: 26.05) : " NIXOS_VERSION
    fi

    read -rp "Nom d'utilisateur : " USERNAME
    FULLNAME="${USERNAME^}"
}

collecter_infos_existantes () {
    echo "══════════════════════════════════════════"
    echo "  Collecte des informations existantes    "
    echo "  Compilation pour variables.nix et       "
    echo "  gestion déclarative                     "
    echo "══════════════════════════════════════════"

    echo "Récupération du username dans le configuration.nix existant"
    USERNAME=$(grep -oP 'users\.users\."\K[^"]+' "$CONFIG_FILE" | head -n1 || true)
    if [[ -z "$USERNAME" ]]; then
        echo "Impossible de détecter automatiquement le nom d'utilisateur dans $CONFIG_FILE."
        read -rp "Entre manuellement ton nom d'utilisateur : " USERNAME
    fi

    echo "Récupération du numero de version nixos dans le configuration.nix déjà existant"
    NIXOS_VERSION=$(grep -oP 'system\.stateVersion\s*=\s*"\K[^"]+' "$CONFIG_FILE" | head -n1 || true)
    if [[ -z "$NIXOS_VERSION" ]]; then
        echo "Impossible de détecter la version NixOS automatiquement."
        read -rp "Entre-la manuellement (ex: 26.05) : " NIXOS_VERSION
    fi

    echo "Récupération du machine-id existant (dans /etc/machine-id)"
    MACHINE_ID=$(cat /etc/machine-id)

    echo "Recherche du nom d'un éventuel sous-volume / distinct"
    ROOT_SUBVOLUME=$(btrfs subvolume show / | head -n1 | xargs)
    if [[ -z "$ROOT_SUBVOLUME" ]]; then
        echo "⚠ Impossible de détecter le nom du subvolume racine."
        read -rp "Entre-le manuellement : " ROOT_SUBVOLUME
    fi

    echo "Récupération de l'UUID LUKS"
    # On detecte quel volume est un volume LUKS
    LUKS_DEVICES=()
    while read -r dev; do
        if cryptsetup isLuks "/dev/$dev" 2>/dev/null; then
            LUKS_DEVICES+=("/dev/$dev")
        fi
    done < <(lsblk -rno NAME,TYPE | awk '$2 == "part" {print $1}')

    case "${#LUKS_DEVICES[@]}" in
        0)
            echo "⚠ Aucune partition LUKS détectée. luksUuid sera laissé vide dans variables.nix."
            LUKS_UUID=""
            ;;
        1)
            echo "Partition LUKS détectée, extraction de l'UUID : ${LUKS_DEVICES[0]}"
            LUKS_UUID=$(cryptsetup luksUUID "${LUKS_DEVICES[0]}")
            ;;
        *)
            echo "Plusieurs partitions LUKS détectées, laquelle utiliser pour l'extraction de l'UUID ?"
            select LUKS_DEVICE in "${LUKS_DEVICES[@]}"; do
                if [[ -n "$LUKS_DEVICE" ]]; then
                    LUKS_UUID=$(cryptsetup luksUUID "$LUKS_DEVICE")
                    break
                fi
                echo "Choix invalide, réessaie."
            done
            ;;
    esac
}

generer_infos_inexistantes () {
    echo "══════════════════════════════════════════"
    echo "  Créer les informations inexistantes     "
    echo "  Compilation pour variables.nix          "
    echo "══════════════════════════════════════════"

    echo "Définition du hostname"
    while true; do
        read -rp "Hostname de cette machine : " HOSTNAME
        if [[ -z "$HOSTNAME" ]]; then
            echo "Le hostname ne peut pas être vide, réessaie."
        elif [[ "$HOSTNAME" =~ [[:space:]] ]]; then
            echo "Le hostname ne doit pas contenir d'espaces, réessaie."
        else
            break
        fi
    done

    echo "Définition du mot de passe déclaratif (hashedPassword)"
    while true; do
        read -rsp "Choisis le mot de passe à hasher : " PASSWORD
        echo ""
        read -rsp "Confirme le mot de passe : " PASSWORD_CONFIRM
        echo ""
        if [[ "$PASSWORD" != "$PASSWORD_CONFIRM" ]]; then
            echo "Les deux saisies ne correspondent pas, réessaie."
        elif [[ -z "$PASSWORD" ]]; then
            echo "Le mot de passe ne peut pas être vide, réessaie."
        else
            break
        fi
    done
    # mkpasswd utilise l'algorythme yescrypt par défaut.
    HASHED_PASSWORD=$(mkpasswd "$PASSWORD")
    # par confidentialité, on ne garde pas en mémoire les valeurs de PASSWORD et PASSWORD_CONFIRM
    unset PASSWORD PASSWORD_CONFIRM
    
    echo "Définition du compte github (facultatif)"
    read -rp "Nom d'utilisateur github (optionnel, peut être laissé vide) : " GIT_USERNAME
    read -rp "Adresse mail github (optionnel, peut être laissé vide) : " GIT_USERMAIL
    echo ""
}

telecharger_repo_git () {
    echo "══════════════════════════════════════════"
    echo "  Téléchargement des .nix depuis le repo  "
    echo "  Github.                                 "
    echo "══════════════════════════════════════════"
    DOTFILES_DIR="${TARGET_MOUNT}/home/${USERNAME}/Git/nixos-dotfiles"

    # Suppression des éventuels fichiers existants (git refuserai de les écraser)
    rm -rf "$DOTFILES_DIR"
    mkdir -p "$DOTFILES_DIR"
    # Installation temporaire de git, et run de la commande
    nix-shell -p git --run "git clone https://github.com/binnotkari-wq/nixos-dotfiles.git $DOTFILES_DIR"
    echo "✓ Dotfiles téléchargés dans ${DOTFILES_DIR}/"

    # Vérification de l'existance du fichier "hostname".nix 
    HOST_IMPORT_PATH="${TARGET_MOUNT}/home/${USERNAME}/Git/nixos-dotfiles/hosts/${HOSTNAME}.nix"
    if [[ -f "$HOST_IMPORT_PATH" ]]; then
        echo "✓ Le fichier de host $HOST_IMPORT_PATH existe bien dans le dépôt."
    else
        echo ""
        echo "⚠ Attention : $HOST_IMPORT_PATH n'existe pas dans le dépôt cloné."
        echo "  Il faudra le créer maintenant sinon le build échouera."
    fi
}

preparer_configuration.nix () {
    echo "══════════════════════════════════════════"
    echo "  Copie de configuration_template.nix     "
    echo "  vers /etc/nixos/configuration.nix puis  "
    echo "  injection des informations collectée    "
    echo "══════════════════════════════════════════"
    mkdir -p "${TARGET_MOUNT}/etc/nixos"
    cp -ra "$DOTFILES_DIR/nixos_deploy/configuration_template.nix" "$CONFIG_FILE"
    # Remplacement des placeholders du numéro de version par celui détecté sur le système en cours, et du username et fullname d'après les informations saisies
    sed -i \
        -e "s|@@username@@|${USERNAME}|g" \
        -e "s|@@fullname@@|${FULLNAME}|g" \
        -e "s|@@nixosversion@@|${NIXOS_VERSION}|g" \
    "$CONFIG_FILE"
    echo "configuration.nix en place : $CONFIG_FILE"
}

sauvegarder_configuration.nix () {
    echo "══════════════════════════════════════════"
    echo "  Sauvegarde de configuration.nix avant   "
    echo "  modifications                           "
    echo "══════════════════════════════════════════"
    BACKUP_FILE="${CONFIG_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    echo "Sauvegarde créée : $BACKUP_FILE"
}

renseigner_configuration.nix () {
    echo "══════════════════════════════════════════"
    echo "  Injection des modifications et          "
    echo "  compléments dans configuration.nix      "
    echo "══════════════════════════════════════════"
    # Insertion de l'import du fichier de host perso, juste après ./hardware-configuration.nix dans le bloc imports
    sed -i "/\.\/hardware-configuration\.nix/a\\      ../../home/${USERNAME}/Git/nixos-dotfiles/hosts/${HOSTNAME}.nix" "$CONFIG_FILE"
    # Remplacement du hostname par défaut ("nixos") par le hostname choisi
    sed -i "s/networking\.hostName = \"nixos\";/networking.hostName = \"${HOSTNAME}\";/" "$CONFIG_FILE"
    # Désactivation de services.xserver.enable
    sed -i 's/services\.xserver\.enable = true;/services.xserver.enable = false;/' "$CONFIG_FILE"
    # Déplacement du displayManager.gdm hors de l'espace xserver (syntaxe actuelle
    sed -i 's/services\.xserver\.displayManager\.gdm\.enable = true;/services.desktopManager.gnome.enable = true;/' "$CONFIG_FILE"
    sed -i 's/services\.xserver\.desktopManager\.gnome\.enable = true;/services.displayManager.gdm.enable = true;/' "$CONFIG_FILE"
    # Désactivation de l'impression
    sed -i 's/services\.printing\.enable = true;/services.printing.enable = false;/' "$CONFIG_FILE"
    # Ajout des groupes supplémentaires pour l'utilisateur
    sed -i 's/[ "networkmanager" "wheel" ];/[ "networkmanager" "wheel" "libvirtd" "kvm" ];/' "$CONFIG_FILE"
    echo "configuration.nix complété."
}

generer_variables.nix () {
    echo "══════════════════════════════════════════"
    echo "  Mise en place de variables.nix          "
    echo "  et injection des informations collectée "
    echo "══════════════════════════════════════════"

    TEMPLATE_FILE="${DOTFILES_DIR}/modules/variables_template.nix"
    VARIABLES_FILE="${DOTFILES_DIR}/modules/variables.nix"
    if [[ ! -f "$TEMPLATE_FILE" ]]; then
        echo "Erreur : $TEMPLATE_FILE introuvable. Vérifie que le clone du dépôt s'est bien déroulé."
        exit 1
    fi

    # Si variables.nix existe déjà (script relancé une deuxième fois), on le
    # sauvegarde avant de l'écraser, comme pour configuration.nix.
    if [[ -f "$VARIABLES_FILE" ]]; then
        VARIABLES_BACKUP="${VARIABLES_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
        cp "$VARIABLES_FILE" "$VARIABLES_BACKUP"
        echo "variables.nix existant sauvegardé : $VARIABLES_BACKUP"
    fi

    cp "$TEMPLATE_FILE" "$VARIABLES_FILE"

    # Fonction d'échappement pour sed : protège \, & et le délimiteur | dans les
    # valeurs injectées (indispensable pour hashedPassword, qui contient des $ et /
    # selon l'algorithme, et qui pourrait théoriquement contenir | ou &).
    sed_escape() {
        printf '%s' "$1" | sed -e 's/[\&|]/\\&/g'
    }

    # Subsitutions
    sed -i "s|@@username@@|$(sed_escape "$USERNAME")|"               "$VARIABLES_FILE"
    # Inutilisé en tant que variable dans les .nix
    # sed -i "s|@@fullname@@|$(sed_escape "$FULLNAME")|"               "$VARIABLES_FILE"
    sed -i "s|@@hashedPassword@@|$(sed_escape "$HASHED_PASSWORD")|"  "$VARIABLES_FILE"
    sed -i "s|@@hostname@@|$(sed_escape "$HOSTNAME")|"               "$VARIABLES_FILE"
    sed -i "s|@@machineid@@|$(sed_escape "$MACHINE_ID")|"            "$VARIABLES_FILE"
    sed -i "s|@@luksUuid@@|$(sed_escape "$LUKS_UUID")|"              "$VARIABLES_FILE"
    sed -i "s|@@nixosversion@@|$(sed_escape "$NIXOS_VERSION")|"      "$VARIABLES_FILE"
    sed -i "s|@@gitUsername@@|$(sed_escape "$GIT_USERNAME")|"        "$VARIABLES_FILE"
    sed -i "s|@@gitUsermail@@|$(sed_escape "$GIT_USERMAIL")|"        "$VARIABLES_FILE"
    sed -i "s|@@rootSubvolumeName@@|$(sed_escape "$ROOT_SUBVOLUME")|" "$VARIABLES_FILE"

    unset HASHED_PASSWORD
    echo "Vérifier le contenu de variables.nix, généré dans $VARIABLES_FILE"
}

installer_Nixos () {
    echo "══════════════════════════════════════════"
    echo "  Installation de Nixos                   "
    echo "══════════════════════════════════════════"
    read -rp "Prêt à installer NixOS ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 0; }
    nixos-generate-config --root /mnt
    echo "✓ hardware-configuration.nix généré (le fichier configuration.nix personnalisé n'a pas été écrasé)"
    echo "Lancement de nixos-install..."
    nixos-install --root /mnt --no-root-passwd
}

rebuilder_Nixos () {
    echo "══════════════════════════════════════════"
    echo "  Rebuild de Nixos (nixos-rebuild boot)   "
    echo "══════════════════════════════════════════"
    read -rp "Prêt à rebuilder NixOS ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 0; }
    echo "Lancement du rebuild..."
    nixos-rebuild boot
}

migrer_fichiers_persistants() {
    echo ""
    echo "══════════════════════════════════════════"
    echo "  PREPARATION IMPERMANENCE                "
    echo "  Migration des dossiers/fichiers à       "
    echo "  persister dans /nix/persist             "
    echo "  Migration à exécuter :                  "
    echo "  - une seule fois                        "
    echo "  - si impermanence.nix est importé       "
    echo "══════════════════════════════════════════"
    read -rp "Prêt à migrer les fichiers à persister ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; return 0; }

    # --- Couleurs -----------------------------------------------------------
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'

    # Création du dossier de persistance
    # /nix est un sous-volume distinct, donc hors périmètre de l'impermanence.
    mkdir -p ${TARGET_MOUNT}/nix/persist

    # Éléments à persister
    # Format : DIRS["source"]="copier_le_contenu"
    #   true  = cp -ra vers /nix/persist (données utiles à conserver)
    #   false = créer le dossier vide dans /nix/persist (se reconstruira tout seul)
    declare -A DIRS
    DIRS["${TARGET_MOUNT}/etc/lact"]="true"
    DIRS["${TARGET_MOUNT}/etc/NetworkManager"]="true"
    DIRS["${TARGET_MOUNT}/etc/nixos"]="true"
    DIRS["${TARGET_MOUNT}/etc/ssh"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/AccountsService"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/bluetooth"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/colord"]="false"
    DIRS["${TARGET_MOUNT}/var/lib/cups"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/flatpak"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/fwupd"]="false"
    DIRS["${TARGET_MOUNT}/var/lib/NetworkManager"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/nixos"]="true"
    DIRS["${TARGET_MOUNT}/var/lib/systemd/coredump"]="false"
    DIRS["${TARGET_MOUNT}/var/lib/upower"]="false"
    DIRS["${TARGET_MOUNT}/var/log"]="true"

    # Traitement
    echo ""
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  Migration initiale vers ${TARGET_MOUNT}/nix/persist${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo ""

    SUCCESS=0
    SKIPPED=0
    CREATED=0
    ERRORS=0

    for src in "${!DIRS[@]}"; do
        copy="${DIRS[$src]}"
        dest="${TARGET_MOUNT}/nix/persist${src#/mnt}"

        # Le dossier source n'existe pas sur /.
        if [[ ! -d "$src" ]]; then
            echo -e "${YELLOW}[ABSENT ]${NC} $src → dossier inexistant sur ${TARGET_MOUNT}/, création vide dans ${TARGET_MOUNT}/nix/persist"
            mkdir -p "$dest"
            (( CREATED++ )) || true
            continue
        fi

        # Le dossier destination existe déjà dans /persist et n'est pas vide.
        if [[ -d "$dest" ]] && [[ -n "$(ls -A "$dest" 2>/dev/null)" ]]; then
            echo -e "${BLUE}[IGNORÉ ]${NC} $dest existe déjà et n'est pas vide, on ne l'écrase pas"
            (( SKIPPED++ )) || true
            continue
        fi

        mkdir -p "$dest"

        if [[ "$copy" == "true" ]]; then
            # Copie du contenu avec préservation des permissions/ownership.
            if cp -ra "$src/." "$dest/" 2>/dev/null; then
                echo -e "${GREEN}[COPIÉ  ]${NC} $src → $dest"
                (( SUCCESS++ )) || true
            else
                echo -e "${RED}[ERREUR ]${NC} $src → échec de la copie"
                (( ERRORS++ )) || true
            fi
        else
            echo -e "${BLUE}[VIDE   ]${NC} $dest créé vide (se reconstruira au boot)"
            (( CREATED++ )) || true
        fi
    done

    # Le contenu éventuel de ce dossier est nécessaire dès le premier démarrage.
    rsync -a ${TARGET_MOUNT}/var/lib/nixos/ ${TARGET_MOUNT}/nix/persist/var/lib/nixos/

    echo -e "${BLUE}======================================================${NC}"
    echo -e "${BLUE}  Résumé${NC}"
    echo -e "${BLUE}======================================================${NC}"
    echo -e "${GREEN}  Copiés    : $SUCCESS${NC}"
    echo -e "${BLUE}  Vides     : $CREATED${NC}"
    echo -e "${YELLOW}  Ignorés   : $SKIPPED${NC}"
    echo -e "${RED}  Erreurs   : $ERRORS${NC}"
    echo ""

    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Des erreurs ont eu lieu, vérifier les dossiers concernés.${NC}"
        exit 1
    else
        echo -e "${GREEN}Migration terminée.${NC}"
    fi
}

finaliser() {
    echo "══════════════════════════════════════════"
    echo "  Téléchargement des scripts utiles depuis"
    echo "  repo github et application permissions  "
    echo "══════════════════════════════════════════"
    # Suppression des éventuels fichiers existants (git refuserai de les écraser)
    rm -rf "${TARGET_MOUNT}/home/${USERNAME}/Git/scripts"
    mkdir -p "${TARGET_MOUNT}/home/${USERNAME}/Git/scripts"
    nix-shell -p git --run "git clone https://github.com/binnotkari-wq/scripts.git ${TARGET_MOUNT}/home/${USERNAME}/Git/scripts/"
    echo "✓ Scripts téléchargés dans ${TARGET_MOUNT}/home/${USERNAME}/Git/scripts/."

    chown -R "1000:1000" "${TARGET_MOUNT}/home/${USERNAME}"
    echo "✓ Permissions appliquées."
    echo ""
    echo "══════════════════════════════════════════"
    echo "  Terminé. Redémarrer le PC.              "
    echo "══════════════════════════════════════════"
}

###############################################################################################
#  EXÉCUTION                                                                                  #
###############################################################################################
# La logique d'éxecution adaptée au conexte : installation ou rebuild
if [ "$TARGET_MOUNT" = "/mnt" ]; then
    read -rp "Prêt à installer NixOS ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; exit 1; }
    executer_installation
elif [ "$TARGET_MOUNT" = "" ]; then
    read -rp "Prêt à rebuilder NixOS ? (oui) : " CONFIRM
    [[ "$CONFIRM" == "oui" ]] || { echo "Annulé."; exit 1; }
    executer_rebuild
fi
