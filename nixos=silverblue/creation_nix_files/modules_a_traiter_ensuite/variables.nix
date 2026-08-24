################################################################################################
# Les scripts bootstrap (déploiement custom) ou post-install (sur une installation standard)   # 
# substitue les @@placeholders@@ automatiquement. Les subsitution sont réalisées APRES avoir   #
# copié et renommé en variables.nix : le repo git est donc anonymisé puisque variables.nix est #
# dans .gitignore et que tous les autres fichiers .nix contiennet le nom de la variable et non #
# sa valeur (----> les .nix sont figés).                                                       #
# Si les scripts ne sont pas utilisés, modiler les @@placeholders@@ manuellement.              #
# Importer ce fichiers dans un des autres nix : les vars sont propagées dans tous les autres   #
# fichiers .nix qui font appel à vars (quels que soient les niveaux d'imports).                #
################################################################################################

{ ... }:

{
                                                # SUR UN SYSTEME DEJA INSTALLE :
  username          = "benoit";           # remplacer par le résultat de getent passwd $USER | cut -d: -f1 | cut -d, -f1
  # fullname          = "@@fullname@@";           # remplacer par le résultat de getent passwd $USER | cut -d: -f5 | cut -d, -f1
  hashedPassword    = "$y$j9T$jgKgONZ0cQPg9wNMp4OIC0$r1VNtxkgC/DNW5n/yI7fZFNc8Oh5VyEVxXsiadDVku8";     # remplacer par le résultat de mkpasswd lemotdepasse (par défaut ce hash sera généré avec l'algorythme yescrypt).
  hostname          = "len-380";           # remplacer par le résultat de hostname
  machineid         = "eec58c7f626b4036ad9dd4c407d7d3e4";          # remplacer par le résultat de systemd-id128 new | tr -d '-'
  luksUuid          = "685f8dd8-fd47-4b10-8a80-28b87ac580b3";           # remplacer par le résultat de sudo cryptsetup luksUUID /dev/nvme0n1p2 (ou autre périphérique qui contient le volume luks - si le volume LUKS porte un nom personnalisé, il faut remplacer par son nom)
  rootSubvolumeName = "root";  # remplacer par le résultat de sudo btrfs subvolume show / | head -n1 | xargs
  nixosVersion      = "26.05";       # remplacer par le résultat de grep "^VERSION_ID=" /etc/os-release | cut -d'"' -f2
  gitUsername       = "binnotkari-wq";        # remplacer par le nom d'utilisateur git
  gitUsermail       = "benoit.dorczynski@gmail.com";        # remplacer par l'email d'utilisateur git

}

################################################################################################
# Import :                                                                                     #
################################################################################################
# { config, pkgs, ... }:
#
# let                                           # ces 3 lignes sont à
#   vars = import ./variables.nix { };          # insérer tout de suite
# in                                            # après { config, pkgs, ... }:
#
# {
#   _module.args.vars = vars;                   # cette ligne est à insérer tout de suite après le premier { ouvert
#
#   imports =
#     [
#       ./un/import.nix
#       ./autre/import.nix
#     ];
#   Le reste
#   du fichier nix
################################################################################################




################################################################################################
# Propagations :                                                                               #
################################################################################################
#   username          # utilisé par impermanence.nix, pseudo-impermanence.nix et home-manager.nix
#   fullname          # inutilisé
#   hashedPassword    # utilisé par impermanence.nix et pseudo-impermanence.nix
#   hostname          # utilisé par impermanence.nix et pseudo-impermanence.nix
#   machineid         # utilisé par impermanence.nix et pseudo-impermanence.nix
#   luksUuid          # utilisé par impermanence.nix
#   rootSubvolumeName # utilisé par impermanence.nix
#   nixosVersion      # utilisé par home-manager.nix
#   gitUsername       # utilisé par git.nix
#   gitUsermail       # utilisé par git.nix
################################################################################################
