##############################################################################
# 100% agnostique, applicable à toute configuration GPU AMD
##############################################################################

{ config, pkgs, lib, ... }:

# infos : si la session steam ne démarre pas, et qu'au bout d'un moment on revient au gestionnaire de login...en fait il faut confgurer
# le client de bureau avant tout (mise à jour, login, langue de l'interface, ajout d'un disque de stockage secondaire...)
# !! Ne pas installer les flatpaks steam, mangohud et gamescope si on active ce module nix

let
  steam-custom-session = pkgs.runCommand "steam-custom-session" {
    passthru.providedSessions = [ "steam-custom" ];
  } ''
    mkdir -p $out/share/wayland-sessions
    cat > $out/share/wayland-sessions/steam-custom.desktop << 'EOF'
[Desktop Entry]
Name=Steam
Comment=Steam (Gamescope et MangoHud)
Exec=${pkgs.gamescope}/bin/gamescope --mangoapp -e -- ${pkgs.steam}/bin/steam -steamdeck -steamos3 -gamepadui
Type=Application
DesktopNames=gamescope
EOF
  '';
in

{
  # 2. On dit au gestionnaire de connexion (SDDM ou GDM) de charger cette session spécifique
  services.displayManager.sessionPackages = [ steam-custom-session ];

  # 3. Règles polkit pour la communication de commandes au système
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.login1.suspend" ||
             action.id == "org.freedesktop.login1.suspend-multiple-sessions" ||
             action.id == "org.freedesktop.login1.reboot" ||
             action.id == "org.freedesktop.login1.power-off") &&
            subject.isInGroup("users")) {
            return polkit.Result.YES;
        }
    });
  '';

  # 4. Paquets et scripts

  programs.gamescope.enable = true;
  programs.steam = {
    enable = true;
    extraPackages = with pkgs; [ mangohud ];                            # on injecte MangoHud directement dans Steam pour MangoApp
    gamescopeSession.enable = false;                                    # on utilise la session custom à la place (gamescope est déclaré dans les pkgs de gaming.nix
  };

  environment.systemPackages = with pkgs; [
    # LE SCRIPT DE RETOUR AU BUREAU
    (pkgs.writeShellScriptBin "steamos-session-select" ''
      # Simule le comportement de SteamOS pour quitter la session
      echo "Fermeture de Steam et retour au DM..."
      ${pkgs.systemd}/bin/loginctl terminate-user ""
    '')
  ];

}
