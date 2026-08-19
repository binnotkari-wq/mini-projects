##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  services.orca.enable = false;                         # service de lecture ecran pour malvoyants. Activé par défaut, mais pesant.
  services.speechd.enable = false;                      # service de lecture ecran pour malvoyants. Accompage Orca. Activé par défaut, mais pesant.
  services.gnome.core-apps.enable = false;              # sans le bundle des apps

  environment.systemPackages = with pkgs; [             # mais on garde celles-ci,  présente dans silverblue
    ptyxis                                              # pour avoir le même terminal que Silverblue
    nautilus
    gnome-control-center
    firefox
    gnome-user-docs
    yelp
    gnome-disk-utility
    gnome-system-monitor
  ];
}
