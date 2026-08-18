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

  # ===========================================================================
  # 1. Contrôle de la présence d'un sous-volume btrfs distinct pour la raince
  #    --> pour la séléction automatique du mode de volatilité de la racine
  # ===========================================================================
let
  utiliserWipe = vars.rootSubvolumeName != "/";
in

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

assertions = [
    {
      assertion = utiliserWipe -> (vars ? luksUuid);
      message = "impermanence.nix : mode wipe sélectionné (rootSubvolumeName != \"/\") mais vars.luksUuid manquant.";
    }
  ];

  # -----------------------------------------------------------------
  # Cas A — pas de sous-volume distinct pour / : tmpfs
  # -----------------------------------------------------------------
  fileSystems."/" = lib.mkIf (!utiliserWipe) (lib.mkForce {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "size=2G" "mode=755" ];
  });

  # -----------------------------------------------------------------
  # Cas B — sous-volume distinct : wipe + restauration d'un snapshot vierge
  # -----------------------------------------------------------------
  boot.initrd.systemd.services.erase_root = lib.mkIf utiliserWipe {
    description = "Efface / en restaurant un snapshot vierge du sous-volume root (btrfs)";
    wantedBy = [ "initrd.target" ];
    unitConfig.DefaultDependencies = "no";
    after = [ "cryptsetup.target" ];
    before = [ "sysroot.mount" ];
    serviceConfig.Type = "oneshot";
    # path = [ pkgs.btrfs-progs pkgs.coreutils pkgs.util-linux ];
    script = ''
set -euo pipefail

  MAPPER="/dev/mapper/luks-${vars.luksUuid}"
  MNT="/mnt-btrfs-toplevel"
  CIBLE="${vars.rootSubvolumeName}"
  VIERGE="${vars.rootSubvolumeName}-blank"

  mount -o subvolid=5,X-mount.mkdir "$MAPPER" "$MNT"

  if [ ! -e "$MNT/$VIERGE" ]; then
    echo "erase_root: $VIERGE introuvable, abandon." >&2
    umount "$MNT"
    exit 1
  fi

  if [ -e "$MNT/$CIBLE" ]; then
    btrfs subvolume delete -R "$MNT/$CIBLE"
  fi

  btrfs subvolume snapshot "$MNT/$VIERGE" "$MNT/$CIBLE"

  umount "$MNT"
    '';
  };
}
