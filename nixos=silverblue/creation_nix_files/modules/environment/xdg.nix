{ config, pkgs, lib, ... }:

{
  # ============================================================
  # 1. DOSSIERS UTILISATEUR XDG PAR DÉFAUT (Globaux)
  # ============================================================
  # On définit la configuration système par défaut pour xdg-user-dirs.
  # Au prochain login, les dossiers seront crées si ~/.config/user-dirs.dirs n'existe pas encore

  environment.etc."xdg/user-dirs.defaults".text = ''
    DESKTOP=Bureau
    DOWNLOAD=Téléchargements
    TEMPLATES=Modèles
    PUBLICSHARE=Public
    DOCUMENTS=Documents
    MUSIC=Mes-Donnees/03_Ressources_Externes/Musique
    PICTURES=Images
    VIDEOS=Vidéos
  '';

  # ============================================================
  # 2. ASSOCIATIONS MIME GLOBALES (Natif NixOS)
  # ============================================================

  xdg.mime = {
    enable = true;
    defaultApplications = {
      "application/x-shellscript" = [ "org.gnome.TextEditor.desktop" ];
      "inode/symlink"             = [ "org.gnome.TextEditor.desktop" ];
      "text/markdown"             = [ "firefox.desktop" ];
      "text/x-markdown"           = [ "firefox.desktop" ];
    };
  };

  # ============================================================
  # 3. RACCOURCIS DESKTOP GLOBAUX
  # ============================================================

  environment.systemPackages = [
    (pkgs.makeDesktopItem {
      name = "llm-start";
      desktopName = "Démarrer LLM";
      exec = "sh -c \"~/Git/scripts/start_llm.sh\"";
      terminal = true;
      icon = "media-playback-start";
      type = "Application";
      comment = "Lance le serveur llama.cpp";
      categories = [ "Education" ];
    })

    (pkgs.makeDesktopItem {
      name = "llm-stop";
      desktopName = "Arrêter LLM";
      exec = "sh -c \"~/Git/scripts/stop_llm.sh\"";
      terminal = false;
      icon = "media-playback-stop";
      type = "Application";
      comment = "Arrête le serveur llama.cpp";
      categories = [ "Education" ];
    })

    (pkgs.makeDesktopItem {
      name = "kiwix";
      desktopName = "Démarrer Kiwix";
      exec = "sh -c \"~/Git/scripts/kiwix-launcher.sh\"";
      terminal = false;
      icon = "accessories-dictionary";
      type = "Application";
      comment = "Lance le serveur Kiwix";
      categories = [ "Education" ];
    })
  ];

# ============================================================
# 4. FICHIERS MODELES GLOBAUX VIA /etc/skel
# ============================================================
# NixOS génère directement ces fichiers dans le squelette système (/etc/skel).
# Ils serviront de base à tout nouvel utilisateur, ou seront copiés par notre service.

environment.etc = {
  "skel/Modèles/Fichier Markdown.md".text = ''
    # H1
    ## H2
    ### H3...etc...

    *Italique*

    **gras**

    ```bash
    # Un commentaire
    cd /usr/bin &&
    Texte aléatoire
    Encadré par ```
    ```
    https://github.com/im-luka/markdown-cheatsheet  
    https://github.com/im-luka/markdown-cheatsheet/blob/main/complete-markdown-cheatsheet.pdf  
  '';

  "skel/Modèles/Fichier texte.txt".text = "";

  # Note : pour rendre le script exécutable dans /etc/skel, 
  # on utilise l'attribut mode de environment.etc
  "skel/Modèles/Script.sh" = {
    mode = "0755";
    text = ''
      #!/usr/bin/env bash
      
      ########################
      # Descriptif du script #
      ########################

    '';
  };

  "skel/Modèles/Fichier nix.nix".text = ''
    #############################
    # Descriptif du fichier nix #
    #############################
    
    { config, pkgs, lib, ... }:

    {

    }
  '';
};

  # Création d'un service exécuté à chaque démarrage pour copier les modèles
  systemd.services.import-skel-templates = {
    description = "Copie et met à jour les modeles globaux dans le dossier personnel de chaque utilisateur";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # On boucle sur tous les utilisateurs réels (UID >= 1000) ayant un dossier /home
      for user_home in /home/*; do
        if [ -d "$user_home" ] && [ -d /etc/skel/Modèles ]; then
          user_name=$(basename "$user_home")
        
          # Créer le dossier Modèles de l'utilisateur s'il n'existe pas
          mkdir -p "$user_home/Modèles"
        
          # Copier en écrasant les fichiers existants (-f pour forcer)
          # On utilise -p pour préserver les permissions (comme le droit d'exécution de Script.sh)
          cp -rfp /etc/skel/Modèles/. "$user_home/Modèles/"
        
          # Rétablir la propriété des fichiers à l'utilisateur concerné
          chown -R "$user_name":users "$user_home/Modèles"
        fi
      done
    '';
  };
}
