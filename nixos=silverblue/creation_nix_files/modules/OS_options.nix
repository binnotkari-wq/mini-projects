##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  # --- 2. BOOTLOADER ---
  boot.kernelParams = [ "quiet" "splash" "loglevel=3" "rd.systemd.show_status=false" ];
  boot.initrd.systemd.enable = true;                      # true est la valeur par défaut à partir de Nixos 26.05. Déclaré au cas où.
  boot.plymouth.enable = true;
  boot.consoleLogLevel = 0;                           # pour désactiver les messages concernant les tables ACPI non documentées, lors du démarrage

  # --- 3. INTERFACES HARDWARE ---
  hardware.bluetooth.enable = true;
  hardware.graphics.enable = true;                        # Vulkan
  services.upower.enable = true;                        # activé defacto sous gnome et kde, mais on le déclare dans le cas où on utilise un D.E light
  services.power-profiles-daemon.enable = true;                 # activé defacto sous gnome et kde, mais on le déclare dans le cas où on utilise un D.E light. Ne pas utiliser tlp, pas pris dans plusieurs D.E.

  # --- 4. MAINTENANCE DU NIX STORE ---
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.settings.auto-optimise-store = true;

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # --- 5. CONFIGURATION LOGICIELLE COMMUNE ---
  security.apparmor.enable = true;                        # l'impact d'apparmor sur les performances est imperceptible. Les flatpaks prennet en charge nativement apparmor.
  # services.fwupd.enable = true;                         # service de mise à jour de firmwares. Si besoin de flasher un firmware.
  services.orca.enable = false;                         # service de lecture ecran pour malvoyants. Activé par défaut, mais pesant.
  services.speechd.enable = false;                        # service de lecture ecran pour malvoyants. Accompage Orca. Activé par défaut, mais pesant.
}
