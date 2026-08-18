##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    handbrake                                                           # (60.7 MiB download, 288.1 MiB unpacked)
    gimp                                                                # (61.0 MiB download, 353.5 MiB unpacked)
    morphosis                                                           # (26.9 MiB download, 208.9 MiB unpacked) (parmis les dépendance : pandoc, qui prend le plus de place)
    drum-machine                                                        # (46.5 MiB download, 258.2 MiB unpacked)
    libreoffice-fresh                                                   # (303.4 MiB download, 1.6 GiB unpacked)
  ];

  # Pour ne pas installer ABiword et Gnumeric qui sont inutiles lorsqu'on installe
  # libreoffice, on override le contenu des paquets en déclarant qu'ils sont vides
  nixpkgs.config.packageOverrides = pkgs: {
    abiword = pkgs.emptyDirectory;
    gnumeric = pkgs.emptyDirectory;
  };
}
