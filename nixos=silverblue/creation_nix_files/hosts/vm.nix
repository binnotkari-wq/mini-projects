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
      # ../modules/drivers_CPU_AMD.nix                                                     # optionnel - intégrable sous conditions (CPU AMD)
      # ../modules/drivers_GPU_AMD.nix                                                     # optionnel - intégrable sous conditions (GPU AMD)
      # ../modules/btop.nix                                                        # optionnel - intégrable sans aucune condition
      ../modules/firefox.nix                                                     # optionnel - intégrable sans aucune condition
      # ../modules/flatpak.nix                                                     # optionnel - intégrable sans aucune condition
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
      # ../modules/software-set_dev_experiments.nix                                      # optionnel - intégrable sans aucune condition
      # ../modules/software-set_firmwares.nix                                            # optionnel - intégrable sans aucune condition. iwlwifi est utilisé par le wifi intel 8260 (dell-5485).
      # ../modules/software-set_gaming.nix                                               # optionnel - intégrable sans aucune condition
      # ../modules/software-set_GTK_all.nix                                              # optionnel - intégrable sans aucune condition
      # ../modules/software-set_GTK_base.nix                                             # optionnel - intégrable sans aucune condition
      # ../modules/software-set_CLI_all.nix                                              # optionnel - intégrable sans aucune condition
      ../modules/software-set_CLI_base.nix                                             # optionnel - intégrable sans aucune condition
      # ../modules/software-set_TUI.nix                                                  # optionnel - intégrable sans aucune condition
      ../modules/software-set_unwanted.nix                                             # optionnel - intégrable sans aucune condition
    ];

  # --- TUNINGS SPECIFIQUES ---
  boot.initrd.kernelModules = [ "virtio_gpu" ];                                                 # GPU virtuel

  services.qemuGuest.enable = true;                                                             # Optimisations spécifiques pour les invités QEMU/KVM

  services.spice-vdagentd.enable = true;                                                        # copier-coller hôte / invité. Ne fonctionne pas avec une session wayland sur l'hote.
  services.spice-webdavd.enable = true;  
}
