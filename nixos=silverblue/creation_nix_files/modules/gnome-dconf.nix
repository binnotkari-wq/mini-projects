##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, lib, ... }:

{
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      lockAll = false; # laisse l'utilisateur ajuster ponctuellement via les Paramètres

      settings = {
        # Clavier
        "org/gnome/desktop/input-sources" = {
          sources = [ (lib.gvariant.mkTuple [ "xkb" "fr+azerty" ]) ];
        };
        "org/gnome/desktop/peripherals/keyboard" = {
          numlock-state = true;
        };

        # Fenêtres / Mutter
        "org/gnome/desktop/wm/keybindings" = {
          maximize   = [ "<Super>Up" ];
          unmaximize = [ "<Super>Down" "<Alt>F5" ];
        };
        "org/gnome/desktop/wm/preferences" = {
          button-layout = ":minimize,maximize,close";
        };
        "org/gnome/mutter" = {
          edge-tiling = true;
        };
        "org/gnome/mutter/keybindings" = {
          toggle-tiled-left  = [ "<Super>Left" ];
          toggle-tiled-right = [ "<Super>Right" ];
        };

        # Apparence
        "org/gnome/desktop/interface" = {
          accent-color = "yellow";
          color-scheme = "prefer-dark";
        };

        # Nautilus
        "org/gnome/nautilus/preferences" = {
          default-folder-viewer = "list-view";
          show-create-link      = true;
          date-time-format      = "detailed";
        };
        "org/gnome/nautilus/list-view" = {
          use-tree-view           = true;
          default-visible-columns = [ "name" "size" "type" "date_modified" ];
        };

        # Vie privée
        "org/gnome/desktop/privacy" = {
          report-technical-problems = false;
        };

        # Sélecteur de fichiers GTK4
        "org/gtk/gtk4/settings/file-chooser" = {
          show-hidden            = true;
          sort-directories-first = true;
        };

        # Éditeur de texte
        "org/gnome/TextEditor" = {
          show-line-numbers      = true;
          highlight-current-line = true;
          restore-session        = false;
          show-map               = true;
          auto-indent            = true;
          indent-style            = "space";
          wrap-text               = false;
          spellcheck              = false;
          recolor-window          = true;
          keybindings             = "default";
          style-variant           = "follow";
          draw-spaces             = [ "space" "tab" "newline" "trailing" "leading" ];
        };

        # Dock : favoris de base
        "org/gnome/shell" = {
          favorite-apps = [
            "kitty.desktop"
            "firefox.desktop"
            "org.gnome.Nautilus.desktop"
            "org.gnome.Console.desktop"
            "org.gnome.TextEditor.desktop"
            "org.gnome.Calculator.desktop"
            "org.gnome.SystemMonitor.desktop"
          ];
        };

        # Extensions
        "org/gnome/shell" = {
          enabled-extensions = [ "dash-to-panel@jderose9.github.com" ];
          disable-user-extensions = false;
        };

        "org/gnome/shell/extensions/dash-to-panel" = {
          dot-position = "BOTTOM";
          intellihide = true;
          hotkeys-overlay-combo = "TEMPORARILY";
          window-preview-title-position = "TOP";
        };

        # Touches multimédia
        "org/gnome/settings-daemon/plugins/media-keys" = {
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name    = "Open Gmail";
          command = "xdg-open https://mail.google.com";
          binding = "XF86Mail";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          name    = "Open Music Player";
          command = "/etc/scripts/open-music-player.sh";
          binding = "XF86Tools";
        };
      };
    }
  ];

  # Script pour la touche lecteur multimédia, déployé au niveau système
  environment.etc."scripts/open-music-player.sh".source = pkgs.writeShellScript "open-music-player" ''
    gnome-music
  '';

}
