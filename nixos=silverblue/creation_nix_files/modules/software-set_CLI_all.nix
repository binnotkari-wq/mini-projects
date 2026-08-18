##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{


  environment.systemPackages = with pkgs; [
    kitty                       # console accelerée GPU, esthétique

    dust                        # analyse graphique de l'espace disque

    # vim                       # Editeur avancé
    duf                         # Visualisation rapide de l'espace disque
    # stow                      # Gestion des dotfiles personnels (inutile lorsqu'on déclare les préférences en .nix)

    cliphist                    # Visualisation de l'historique du presse-papier
    # atuin                     # analyse de l'historique bash. Mais par rappor à la confidentialité ....non (synchro de l'historique en ligne, etc...)
    groff
    imagemagick
    pandoc
  ];
}
