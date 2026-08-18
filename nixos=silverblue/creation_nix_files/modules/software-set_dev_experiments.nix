##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    gnome-boxes # (33.7 MiB download, 187.2 MiB unpacked)
    distroshelf # (2.8 MiB download, 15.2 MiB unpacked)

    # --- Développement & Data ---

  ];



  # --- VIRTUALISATION ---
  virtualisation.libvirtd.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;
}
