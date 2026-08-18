##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    steam-run                                   # crée un environnement FHS à la volée, pratique pour exécuter un vieux binaireo u jeu isolé natif linux, sans avoir à maintenir un container.
    SDL2                                        # pour d'anciens jeux qui utilisent SDL
    mangohud
    warzone2100
    hydralauncher
  ];

  services.lact.enable = true;                  # (en natif, car ne fonctionne pas en flatpak, ne peut pas installer le service)

  programs.steam = {
    enable = true;
    extraPackages = with pkgs; [ mangohud ];    # On injecte MangoHud directement dans Steam pour MangoApp
  };
}
