##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, lib, ... }:

{

  options = {
    # --- 1. OPTIONS PAR DEFAUT LUKS ET BTRFS ---

    ##############################################################################
    # Définit les options à passer par défaut à tout volume LUKS.
    # Pour vérifier que les options sont bien passées : sudo dmsetup table
    ##############################################################################
    boot.initrd.luks.devices = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        config = {
          allowDiscards = lib.mkDefault true;
          bypassWorkqueues = lib.mkDefault true;
        };
      });
    };

    ##############################################################################
    # Définit les options à passer par défaut à tout système de fichier BTRFS.
    # Pour vérifier que les options sont bien passées :
    # cat /proc/mounts | grep btrfs et cat /etc/fstab
    ##############################################################################
    fileSystems = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({ config, ... }: {
        config = lib.mkIf (config.fsType == "btrfs") {
          options = [ "noatime" "compress=zstd" "ssd" "discard=async" ];
        };
      }));
    };
  };

  config = {
    # --- 2. OPTIMiSATIONS KERNEL ---
    
    ##############################################################################
    # NTSync — accélère les primitives de synchronisation NT utilisées par
    # Wine/Proton (équivalent moderne de esync/fsync). Gain de FPS mesurable
    # dans certains jeux Windows lancés via Proton. Nécessite un noyau récent
    # qui inclut le module (c'est le cas des noyaux mainline récents).
    ##############################################################################
    boot.kernelModules = [ "ntsync" ];

    ##############################################################################
    # earlyoom — tue les processus les plus gourmands en mémoire *avant* que
    # le système ne sature complètement et ne freeze. Filet de sécurité léger,
    # particulièrement utile en jeu où un freeze total est plus pénible qu'un
    # simple crash d'un processus.
    ##############################################################################
    services.earlyoom = {
      enable = true;
      freeMemThreshold = 5; # déclenche si RAM libre < 5%
    };

    ##############################################################################
    # GameMode is a daemon/lib combo for Linux that allows games to request a set
    # of optimisations be temporarily applied to the host OS and/or a game process.
    # GameMode was designed primarily as a stop-gap solution to problems with the 
    # Intel and AMD CPU powersave or ondemand governors, but is now host to a range
    # of optimisation features and configurations.
    ##############################################################################
    programs.gamemode.enable = true;

    ##############################################################################
    # SWAP / ZRAMAvec 8 Go de RAM, un ZRAM bien dimensionné suffit largement pour 
    # une machine de bureau ou un laptop classique. Cela rend le swap sur dique inutile.
    ##############################################################################
    zramSwap.enable = true;
    zramSwap.algorithm = "zstd";
    zramSwap.priority = 100;                                                    # sera utilisé en priorité avant le swap sur disque (s'il existe)
    zramSwap.memoryPercent = 100;                                               # Utilise jusqu'à 100% de la RAM
    boot.kernel.sysctl = {
    "vm.swappiness" = 150;                                                      # Le noyau va commencer à envoyer des plages mémoire en zram sans attendre la saturation
    };

    # --- 3. OPTIMISATIONS BTRFS (https://wiki.nixos.org/wiki/Btrfs) ---
    boot.kernelParams = [ 
      "btrfs.clear_cache" 
    ];

    # tout disque BTRFS secondaire monté ultérieurement par udev (gestionnaire de fichier) bénéficiera de ces options :
    services.udisks2.settings = {
      "mount_options.conf" = {
        defaults = {
          btrfs_defaults = "nosuid,nodev,noatime,compress=zstd,ssd,discard=async";
          # ssd,discard=async sont retirés, au cas où il y ait un disque non ssd
          # btrfs_defaults = "nosuid,nodev,noatime,compress=zstd";
        };
      };
    };

    services.fstrim.enable = true;                                                # activé de facto, mais on le déclare explicitement

    # les filesystems /, /nix et /home sont également créés par Calamares.
    # NB : grâce à options.fileSystems = lib.mkOption, ces déclaration ne sont plus nécessaires.
    #fileSystems."/".options = [ "noatime" "compress=zstd" "ssd" "discard=async" ];
    #fileSystems."/nix".options = [ "noatime" "compress=zstd" "ssd" "discard=async" ];
    #fileSystems."/home".options = [ "noatime" "compress=zstd" "ssd" "discard=async" ];
  };  
}
