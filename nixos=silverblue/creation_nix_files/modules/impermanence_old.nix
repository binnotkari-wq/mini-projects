#################################################################################################################################
# PAS AGNOSTIQUE.

# PREREQUIS :
# - il faut un sous-volume ou partition distint de / . C'est le setup standard de Calamares lorsqu'on choisi le système de fichier
#   BRTFS, les sous-volumes /nix et /home sont automatiquement crées. Pour ext4, il faut créer une partition distincte pour /nix
#   (le store sera ainsi en dehors de la volatilité) ainsi que pour /home, et éventuellement une partition distincte pour les
#   éléments à persister si on veut les placer ailleurs que dans le volume /nix ou /home
 #  
# - la méthode de volatilité "subvol_reset" n'est utilisable qu'avec un système de fichier BTRFS dans lequel un sous-volume distinct
#   (donc avec top-level = 5) a été créé pour /. Le système de fichier BTRFS doit être dans un volume encrypté LUKS.
#   Si cette condition n'est pas remplie, la méthode de volatilité doit être "tmpfs" (à choisir plus bas)
#
# - les éléments de / à persister doivent être copiés au préalable sur l'emplacement de persistance, avec cp -ra
#
#
# IMPERMANENCE
#
# Wipe :
# Au démarrage, la racine (/) est rendue volatile — soit via tmpfs, soit via un sous-volume btrfs supprimé puis recrée au
# démarrage. Tout ce qui n'est pas explicitement sauvé disparaît au reboot : logs, caches, fichiers générés à la volée, erreurs
# de manipulation — le système repart "propre" à chaque fois.
#
# Persistences :
# Une partie de ces éléments d'état impératif méritent d'être intentionnellement persistés (clés SSH, configs wifi et bluetooth,
# /var/lib de services, /home ). On désigne un sous-volume ou partition distincte, en dehors du cycle de wipe, pour placer le dossier
# de ces éléments à persister.
#
# Liaison / vers persistences
# Le lien entre le / éphémère et ce stockage persistant se fait de deux façons, après le wipe complet de / : par bind-mounts
# déclarés (ex. /etc/machine-id, /var/lib/bluetooth) qui exposent un chemin persistant à l'endroit attendu, et par liens
# symboliques régénérés à chaque boot via systemd.tmpfiles.rules
# 
# Non conernés :
# * Le Nix store (/nix/store) est le résultat d'un état déclaratif, immuable et versionné par hash, sur son propre sous-volume (/nix).
#   Sa persistance n'est pas une exception qu'on gère, elle est structurelle.
# * Les partitions et les sous-volume distinct de / sont par défaut en dehors de toute volatilité (il faudrait les monter en tmpfs
#   ou les inclure dans le script de wipe) car voués à stocker des données stockées intentionnellement par l'utilisateur.
#
# Module communautaire vs mise en place native
# Le module nix-community/impermanence abstrait tout le mécanisme : on déclare une simple liste de chemins
# (environment.persistence."/persist".directories = [...]), et il génère lui-même les bind-mounts, l'ordre de montage, les permissions.
# Mais la logique reste cachée dans les internals du module.
# La mise en place native (bind mounts manuels via fileSystems, règles tmpfiles écrites à la main) exige de comprendre chaque mécanisme
# mis en œuvre, mais offre en retour une lecture horizontale complète de la configuration : rien n'est masqué derrière une couche
# d'abstraction, chaque montage est visible et modifiable directement, au prix d'un peu plus de verbosité. On évite aussi une
# dépendance extérieure.
#################################################################################################################################



#################################################################################################################################
# Les vars sont hérités de variables.nix. Si on n'utilise pas les variables, remplacer :
# - ${vars.machineid} par le résultat de : systemd-id128 new | tr -d '-'
# - ${vars.username} par le nom de l'utilisateur
# - vars.hashedPassword par le résultat de : mkpasswd lemotdepasse (par défaut ce hash sera généré avec l'algorythme yescrypt).
# - ${vars.rootSubvolumeName} par le résultat de : sudo btrfs subvolume show / | cut -f1
# - ${vars.luksUuid} par le résultat de : sudo cryptsetup luksUUID /dev/nvme0n1p2 (ou autre périphérique qui contient le volume luks)
# - ----> si le volume LUKS porte un nom personnalisé, il faut remplacer luks-${vars.luksUuid} par son nom.
#################################################################################################################################

{ config, lib, pkgs, vars, ... }:

{
  # ===========================================================================
  # 1. Options systèmes
  # ===========================================================================

  # fileSystems."/persist".neededForBoot = true; # on s'assure que /persist sera monté très tôt lors du démarrage. Utile uniquement quand on utilise un sous-volume dédié.

  # --- IDENTIFIANTS DECLARATIFS ---
  # Pour que /etc/machine-id, /etc/shadow, /etc/passwd et /etc/group soient gérés déclarativement (initialement, ils sont créés de façon iméprative par Calamares).
  # En effet la séquence de boot supporte mal la mise en persistance de ces fichiers. Certains services peuvent essayer d'y accéder, alors que les liens symboliques
  # défini par impermanence ne sont pas encore reconstruits.
  # A commenter si déjà déclarées dans un autre .nix.
  environment.etc."machine-id".text = "${vars.machineid}\n";
  users.users.${vars.username}.hashedPassword = vars.hashedPassword;
  users.mutableUsers = false;

  # ===========================================================================
  # 2. bind mount des dossiers à persister
  # ===========================================================================
  # (x-gvfs-hide : cache le point de montage dans les gestionnaires de fichiers GNOME)
  # On peut vérifier la bonne création des bind-mounts avec findmnt -n -t btrfs -o UUID,TARGET --list

  fileSystems = {
    # Commenter les éléments qui font l'objet d'une gestion déclarative ou qui existent déjà sur un volume distinct.
    # "/home"                   = { device = "/nix/persist/home"                        ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/etc/lact"                 = { device = "/nix/persist/etc/lact"                    ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/etc/NetworkManager"       = { device = "/nix/persist/etc/NetworkManager"          ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/etc/nixos"                = { device = "/nix/persist/etc/nixos"                   ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/etc/ssh"                  = { device = "/nix/persist/etc/ssh"                     ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/AccountsService"  = { device = "/nix/persist/var/lib/AccountsService"     ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/bluetooth"        = { device = "/nix/persist/var/lib/bluetooth"           ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/colord"           = { device = "/nix/persist/var/lib/colord"              ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/cups"             = { device = "/nix/persist/var/lib/cups"                ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/flatpak"          = { device = "/nix/persist/var/lib/flatpak"             ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/fwupd"            = { device = "/nix/persist/var/lib/fwupd"               ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/NetworkManager"   = { device = "/nix/persist/var/lib/NetworkManager"      ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/nixos"            = { device = "/nix/persist/var/lib/nixos"               ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/systemd/coredump" = { device = "/nix/persist/var/lib/systemd/coredump"    ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/lib/upower"           = { device = "/nix/persist/var/lib/upower"              ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
    "/var/log"                  = { device = "/nix/persist/var/log"                     ; fsType = "none"; options = [ "bind" "x-gvfs-hide" ]; neededForBoot = true; };
  };

  # ===========================================================================
  # 3. fichiers individuels à persister
  # ===========================================================================
  systemd.tmpfiles.rules = [

    # Liens symboliques pour les FICHIERS individuels persistés.
    # "L+" force la (re)création du lien si la cible n'existe pas déjà à cet
    # emplacement (donc jamais de conflit après le wipe de "/" au reboot).
    # Format : "L+ <chemin destination> - - - - <chemin source dans /nix/persist>"
    #
    # Commenter les éléments qui font l'objet d'une gestion déclarative ou qui existent déjà sur un volume distinct.
    # "L+ /etc/machine-id - - - - /nix/persist/etc/machine-id"                          # identifiant unique de la machine, doit être stable dans le temps
    # "L+ /etc/adjtime - - - - /nix/persist/etc/adjtime"                                # dérive mesurée de l'horloge matérielle (RTC), inutile de la reperdre
    # "L+ /root/.rnd - - - - /nix/persist/root/.rnd"                                    # graine aléatoire OpenSSL, à ne pas régénérer à chaque boot

  # ===========================================================================
  # 4. contrôles
  # ===========================================================================

    # --- 4a. Existence des dossiers SOURCES dans /nix/persist ---
    # systemd vérifiera à chaque démarrage que les dossiers persistés existent bien, ont les bonnes permissions.
    # Dans le cas contraire, il créé les dossier et / ou aplique les bonnes pemrissions.
    # Format : "d <chemin> <perms> <user> <group> -"

    "d /nix/persist/etc/lact 0755 root root -"
    "d /nix/persist/etc/NetworkManager 0755 root root -"
    "d /nix/persist/etc/nixos 0755 root root -"
    "d /nix/persist/etc/ssh 0755 root root -"
    "d /nix/persist/var/lib/AccountsService 0775 root root -"                           # perm custom : lue par accounts-daemon en 0775
    "d /nix/persist/var/lib/bluetooth 0700 root root -"                                 # perm custom : données bluetooth sensibles, 0700
    "d /nix/persist/var/lib/colord 0755 colord colord -"                                # perm custom : appartient à l'utilisateur système colord
    "d /nix/persist/var/lib/cups 0755 root root -"
    "d /nix/persist/var/lib/flatpak 0755 root root -"
    "d /nix/persist/var/lib/fwupd 0755 root root -"
    "d /nix/persist/var/lib/NetworkManager 0755 root root -"
    "d /nix/persist/var/lib/nixos 0755 root root -"
    "d /nix/persist/var/lib/systemd/coredump 0755 root root -"
    "d /nix/persist/var/lib/upower 0755 root root -"
    "d /nix/persist/var/log 0755 root root -"
  ];

  # --- 4b. Ordonnancement systemd : création des dossiers sources avant les bind-mounts ---
  # Un nom de .mount = chemin absolu, "/" remplacé par "-", sans le "/" initial.
  systemd.services.systemd-tmpfiles-setup.before = [
    "etc-lact.mount"
    "etc-NetworkManager.mount"
    "etc-nixos.mount"
    "etc-ssh.mount"
    "var-lib-AccountsService.mount"
    "var-lib-bluetooth.mount"
    "var-lib-colord.mount"
    "var-lib-cups.mount"
    "var-lib-flatpak.mount"
    "var-lib-fwupd.mount"
    "var-lib-NetworkManager.mount"
    "var-lib-nixos.mount"
    "var-lib-systemd-coredump.mount"
    "var-lib-upower.mount"
    "var-log.mount"
  ];

  # ===========================================================================
  # 5. reset du root
  # ===========================================================================

  # Deux solutions :
  # - tmpfs : universel, pas de prérequis
  # - wipe btrfs : sous-volume btrfs pour /

  # ROOT EN TMPFS
  # Section inutile lorsque root est un sous-volume BTRFS qu'on wipe au démarrage du PC, à commenter dans ce cas.
  # Montage de / en tmpfs (ce paramétrage prend le dessus sur celui de hardware-configuration.nix)
  fileSystems."/" = lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2G" "mode=755" ];
  };

  # WIPE DU SOUS-VOUME BTRFS ROOT - POSSIBLE UNIQUEMENT SI LUKS->VOLUME BTRFS->SOUS VOLUME DISTINCT POUR /
  # Un service sera exécuté par systemd à chaque démarrage pour vider root
  # Section inutile lorsque / est un tmpfs qui se vide à l'exctinction / redémarrage, à commenter dans ce cas.
  # L'activation de cette section suppose que :
  # - il y a un volume LUKS
  # - il y a un sous-volume root et il est nommé root
  # Cette configuration de système de fichier est créée par bootstrap.sh mais pas par Calamares, qui ne créé pas de sous-solume distinct pour root.
  #  boot.initrd.systemd.services.erase_root = {
  #    description = "Vidange du filesystem root à chaque boot";
  #    wantedBy = [ "initrd.target" ];
  #    after = [ "systemd-cryptsetup@${lib.replaceStrings ["-"] ["\\x2d"] "luks-${vars.luksUuid}"}.service" ];
  #    before = [ "sysroot.mount" ];
  #    unitConfig.DefaultDependencies = "no";
  #    serviceConfig.Type = "oneshot";
  #    script = ''
  #set -euo pipefail

  #  ROOT_SUBVOL="${vars.rootSubvolumeName}"
  #  MNT="/sysroot"

  #  mount --mkdir -t btrfs -o subvol=/ /dev/mapper/luks-${vars.luksUuid} "$MNT"
  #  trap 'umount -l "$MNT" 2>/dev/null || true' EXIT

   # info=$(btrfs subvolume show "$MNT/$ROOT_SUBVOL")
  #  top_level_id=""
  #  while IFS= read -r line; do
  #    case "$line" in
  #      *"Top level ID:"*)
  #        top_level_id="''${line##*:}"
  #        top_level_id="''${top_level_id//[[:space:]]/}"
  #        ;;
  #    esac
  #  done <<< "$info"

  #  if [ "$top_level_id" != "5" ]; then
  #    echo "ERREUR FATALE : '$ROOT_SUBVOL' n'est pas un sous-volume enfant du top-level (Top level ID=$top_level_id)." >&2
  #    echo "Layout inattendu (ex: install Calamares sans sous-volume dédié). Abandon du wipe." >&2
  #    exit 1
  #  fi

  #  btrfs subvolume delete -R "$MNT/$ROOT_SUBVOL"
  #  btrfs subvolume create "$MNT/$ROOT_SUBVOL"
  #    '';
  #  };
}
