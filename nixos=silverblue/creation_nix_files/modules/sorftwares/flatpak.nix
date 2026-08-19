##############################################################################
# 100% agnostique, applicable à toute configuration                          #
# Ce module permet une gestion déclarative et automatisée des flatpaks, en   #
# utilisant uniquement les fonctions standards exposées par Nixos (-> pas de #
# dépendance à un module communautaire tel que /nix-flatpak) .               #
##############################################################################

{ config, lib, pkgs, ... }:

with lib;
let
  cfg = config.custom.flatpak;
  # Premier repo de la liste = remote par défaut pour les installations
  defaultRemote = if cfg.remotes != [] then elemAt (elemAt cfg.remotes 0) 0 else "flathub";
in
{
  config = mkMerge [
    {

##############################################################################
# Sélections à renseigner et options de configuration.                       #
##############################################################################
      services.flatpak.enable = true;
      custom.flatpak.enable = true;
      custom.flatpak.uninstallUnmanaged  = false;                # désinstalle tout flatpak absent de la lsite déclarée

      # Liste de dépôts, chaque entrée = [ "nom" "url" ]. Le premier repo de la liste sert de remote par défaut.
      custom.flatpak.remotes = [
        [ "flathub" "https://dl.flathub.org/repo/flathub.flatpakrepo" ]
        # [ "flathub-verified" "https://dl.flathub.org/repo/flathub.flatpakrepo" ]
      ];

      custom.flatpak.packages = [
        # "org.gnome.gitlab.somas.Apostrophe"                   # Préférer Marker en pkg : contrairement à Apostrophe en pkg, ne tire quasi aucune dépendance
        # "org.libreoffice.LibreOffice"                         # Préférer la version pkgs nix
        # "com.heroicgameslauncher.hgl"                         # Préférer la version pkgs nix
        # "net.lutris.Lutris"                                   # Heroic gère très bien Sketchup (seul logiciel windows utilisé)
        # "com.usebottles.bottles"                              # Heroic gère très bien Sketchup (seul logiciel windows utilisé)
        # "com.valvesoftware.Steam"                             # Préférer la version pkgs nix
        # "com.valvesoftware.Steam.CompatibilityTool.Proton-GE" # Préférer la version pkgs nix
        # "io.github.flattool.Warehouse"                        # Utile pour une gestion avancée des Flatpaks
        # "com.github.tchx84.Flatseal"                          # Utile pour certains Flatpaks qui nécessitent une gestion fine des permissions
        # "net.retrodeck.retrodeck"                             # Usine à gaz, préférer quelques émulateurs dédiés
        # "org.libretro.RetroArch"                              # Usine à gaz, préférer quelques émulateurs dédiés
      ];
##############################################################################
# Fin des sélections à renseigner et options de configuration.               #
##############################################################################



##############################################################################
# Logique et intégration système                                             #
##############################################################################
      # Intégration dans l'environnement des chemins des fichiers de raccourcis .desktop
      environment.sessionVariables = {
        XDG_DATA_DIRS = [
          "/var/lib/flatpak/exports/share"
          "$HOME/.local/share/flatpak/exports/share"
        ];
      };

    }

    (mkIf cfg.enable {

      # Aucune unit systemd créée : juste un script shell exécuté en synchrone
      # pendant l'activation (nixos-rebuild switch/boot/test, et au démarrage
      # du système puisque NixOS réactive le profil courant à chaque boot).
      system.activationScripts.flatpakSync = {
        text = ''
          echo "=== flatpakSync: réconciliation des dépôts et paquets Flatpak ==="

          # --- 1) Dépôts : toujours exécuté, indépendant de uninstallUnmanaged ---
          ${concatMapStringsSep "\n" (repo: ''
            ${pkgs.flatpak}/bin/flatpak remote-add --if-not-exists \
              ${escapeShellArg (elemAt repo 0)} ${escapeShellArg (elemAt repo 1)} \
              || echo "flatpakSync: avertissement, remote-add ${elemAt repo 0} a échoué (pas de réseau ?)"
          '') cfg.remotes}

          # --- 2) Installation des paquets désirés ---
          ${concatMapStringsSep "\n" (appId: ''
            if ! ${pkgs.flatpak}/bin/flatpak info --system ${escapeShellArg appId} >/dev/null 2>&1; then
              echo "flatpakSync: installation de ${appId}"
              ${pkgs.flatpak}/bin/flatpak install -y --system --noninteractive \
                ${escapeShellArg defaultRemote} ${escapeShellArg appId} \
                || echo "flatpakSync: avertissement, installation de ${appId} a échoué (pas de réseau au boot ?)"
            fi
          '') cfg.packages}

          ${optionalString cfg.uninstallUnmanaged ''
            # --- 3) Suppression des paquets non déclarés (uniquement si uninstallUnmanaged = true) ---
            desired="${concatStringsSep " " cfg.packages}"
            for app in $(${pkgs.flatpak}/bin/flatpak list --app --system --columns=application 2>/dev/null); do
              if ! echo "$desired" | grep -qw "$app"; then
                echo "flatpakSync: suppression de $app (non déclaré, uninstallUnmanaged=true)"
                ${pkgs.flatpak}/bin/flatpak uninstall -y --system --noninteractive "$app" \
                  || echo "flatpakSync: avertissement, désinstallation de $app a échoué"
              fi
            done
          ''}

          echo "=== flatpakSync: terminé ==="
        '';
      };
    })
  ];

  options.custom.flatpak = {
    enable = mkEnableOption "gestion des Flatpaks (services.flatpak + réconciliation au rebuild)";
    uninstallUnmanaged = mkOption { type = types.bool; default = false; };
    remotes = mkOption { type = types.listOf (types.listOf types.str); default = [ [ "flathub" "https://dl.flathub.org/repo/flathub.flatpakrepo" ] ]; };
    packages = mkOption { type = types.listOf types.str; default = []; };
  };

}
##############################################################################
# Fin de la logique et intégration système                                   #
##############################################################################
