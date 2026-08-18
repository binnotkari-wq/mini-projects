{ config, pkgs, lib, ... }:

{

  # Charger le driver nvidia Wayland
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    # Modesetting est requis pour la plupart des compositeurs Wayland (Hyprland, Sway, etc.)
    modesetting.enable = true;

    # Utiliser les modules kernel open-source de NVIDIA (recommandé pour RTX 30xx)
    # si problèmes graphiques, essayer de mettre 'false'
    # open = true  → RTX 30xx+ (Turing+) uniquement
    # open = false → GTX, anciennes générations
    open = true;

    # Activer le menu de configuration NVIDIA
    nvidiaSettings = true;

    # Sélectionner le package de pilotes (stable est généralement le meilleur choix)
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

}
