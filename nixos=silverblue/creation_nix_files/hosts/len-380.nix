#########################################################################################
# Spécifique à la machine.                                                              #
# Déclare uniquement ce qui ne peut concerner une autre machine.                        #
#########################################################################################

{ config, pkgs, ... }:

let
  vars = import ../modules/variables.nix { };                                    # génération par bootstrap.sh ou adaptation manuelle
in

{
  _module.args.vars = vars;

  imports =
    [
      ../modules/cargo.nix
      ../modules/drivers_CPU_intel_pre10.nix                                             # optionnel - intégrable sous conditions (CPU intel avant gen10)
      ../modules/drivers_iGPU_intel.nix                                                  # optionnel - intégrable sous conditions (GPU intel intégré)
      # ../modules/btop.nix                                                        # optionnel - intégrable sans aucune condition
      ../modules/firefox.nix                                                     # optionnel - intégrable sans aucune condition
      ../modules/flatpak.nix                                                     # optionnel - intégrable sans aucune condition
      ../modules/git.nix                                                         # optionnel - intégrable sous conditions (variables.nix ou adaptation manuelle)
      ../modules/gnome-dconf.nix                                                 # optionnel - intégrable sans aucune condition
      ../modules/impermanence.nix                                                # optionnel - intégrable sous conditions (variables.nix ou adaptation manuelle)
      # ../modules/kitty.nix                                                       # optionnel - intégrable sans aucune condition
      ../modules/OS_options.nix                                                  # optionnel - intégrable sans aucune condition
      # ../modules/newsboat.nix                                                    # optionnel - intégrable sans aucune condition
      ../modules/performance_addons.nix                                          # optionnel - intégrable sans aucune condition
      # ../modules/pyradio.nix                                                     # optionnel - intégrable sans aucune condition
      ../modules/shell.nix                                                       # optionnel - intégrable sans aucune condition
      # ../pseudo_impermanence.nix                                               # optionnel - intégrable sous conditions (variables.nix ou adaptation manuelle)
      # ../modules/SteamOS.nix                                                     # optionnel - intégrable sans aucune condition (mais utilisable seulement avec GPU AMD)
      ../modules/xdg.nix                                                         # optionnel - intégrable sans aucune condition
      ../modules/software-set_dev_experiments.nix                                      # optionnel - intégrable sans aucune condition
      ../modules/software-set_firmwares.nix                                            # optionnel - intégrable sans aucune condition. iwlwifi est utilisé par le wifi intel 8260 (dell-5485).
      # ../modules/software-set_gaming.nix                                               # optionnel - intégrable sans aucune condition
      # ../modules/software-set_GTK_all.nix                                              # optionnel - intégrable sans aucune condition
      ../modules/software-set_GTK_base.nix                                             # optionnel - intégrable sans aucune condition
      # ../modules/software-set_CLI_all.nix                                              # optionnel - intégrable sans aucune condition
      ../modules/software-set_CLI_base.nix                                             # optionnel - intégrable sans aucune condition
      # ../modules/software-set_TUI.nix                                                  # optionnel - intégrable sans aucune condition
      ../modules/software-set_unwanted.nix                                             # optionnel - intégrable sans aucune condition
    ];

  # --- TDP ---
  powerManagement.powertop.enable = true;                                                       # met en place un service qui applique automatiquement les réglages appliqués. Utiliser seulement sur PC portables.
  # A ADAPTER POUR LE L380
  # Le X240 est parfaitement stable en stress-test avec ces valeurs (et le boost est maintenu, avec une température de moins de 70 degrés!)
  # services.undervolt = {
    # enable = true;
    # coreOffset = -40;                                                                         # Valeur en mV (-80 pour commencer : kernel panic lors du débranchement de l'alim)
    # gpuOffset = -40;                                                                          # L'iGPU peut aussi être undervolté
    # uncoreOffset = -40;                                                                       # Contrôleur mémoire, etc.
    # analogioOffset = 0;                                                                       # Généralement laissé à 0
    # temp = 75;                                                                                # Paramètre optionnel : définit la limite de température avant throttling
  # };


# blocage dongle logitech usb (power control en auto) cf discussion Claude "Souris USB Logitech qui se fige sous NixOS". Reproduire memes manips pour le clavier si jamais.

systemd.services."usb-logitech-power-fix" = { ... };
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="046d", ATTR{idProduct}=="c52b", TAG+="systemd", ENV{SYSTEMD_WANTS}+="usb-logitech-power-fix.service"
'';

# Le driver hid_logitech_dj réinitialise power/control="auto" après le bind USB,
# à un timing variable. Un simple RUN+= udev ne suffit pas : on force la valeur
# plusieurs fois sur 10s pour être sûr de gagner contre le reset du driver.
# Ce service : attend 3s après le déclenchement, puis force on plusieurs fois toutes les 2s pendant 10s — assez pour couvrir n'importe quel moment où le driver réinitialiserait la valeur.
systemd.services."usb-logitech-power-fix" = {
  description = "Force USB power/control=on for Logitech Unifying receiver";
  serviceConfig = {
    Type = "oneshot";
    ExecStart = pkgs.writeShellScript "fix-logitech-power" ''
      sleep 3
      for i in 1 2 3 4 5; do
        for dev in /sys/bus/usb/devices/*/; do
          if [ -f "$dev/idVendor" ] && [ "$(cat "$dev/idVendor")" = "046d" ] && [ "$(cat "$dev/idProduct")" = "c52b" ]; then
            echo on > "$dev/power/control"
          fi
        done
        sleep 2
      done
    '';
  };
};

}
