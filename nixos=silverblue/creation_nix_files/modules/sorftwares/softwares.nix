##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  hardware.enableRedistributableFirmware = true;                                # pour avoir des firmware supplémentaire open-source (wifi...). 750 Mo.
  # hardware.enableAllFirmware = true;                                          # pour avoir des firmware closed source (matériel spécifique...)


# INTEGRER  REPO FLATHUB (dans /etc/flatpak/remotes.d/flathub.flatpakrepo ? -> Flatpak system-wide remotes are saved in /etc/flatpak/remotes.d/ and /usr/share/flatpak/remotes.d/, with files under /etc taking precedence if duplicates exist. Per-user remotes are stored in ~/.local/share/flatpak/repo/config. On pourrait créer avec un environment.etc)
  services.flatpak.enable = true;


  services.lact.enable = true;                  # (en natif, car ne fonctionne pas en flatpak, ne peut pas installer le service)
  security.apparmor.enable = true;                        # l'impact d'apparmor sur les performances est imperceptible. Les flatpaks prennet en charge nativement apparmor.
  services.fwupd.enable = true;                           # service de mise à jour de firmwares. Si besoin de flasher un firmware.

  # Activation de la recherche contenu / metadata dans gnome
  services.gnome.localsearch.enable = true;
  services.gnome.tinysparql.enable = true;
  
  # on expose gstreamer aux plugins (qui ne peuvent pas savoir où chercher dans le FHS spécifique nixos)
  environment.sessionVariables = {
    GST_PLUGIN_SYSTEM_PATH_1_0 = "/run/current-system/sw/lib/gstreamer-1.0";
  };

  # --- ZOXYDE ---

  programs.zoxide = {           # cd intelligent. Commencer par lancer zoxide add "le répertoire à intégrer dans la base de données". Puis, z remplace cd (pas immédiat, il faut déjà se promener un peu dans les dossiers)
    enable = true;
    enableBashIntegration = true;
  };

  environment.interactiveShellInit = ''
    # Intégration zoxide
    eval "$(zoxide init bash)"
  '';

  # --- PODMAN ---

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;                                # Permet compatibilité docker si nécessaire
    defaultNetwork.settings.dns_enabled = true;         # Active le DNS interne pour les conteneurs
  };

  # Active user namespaces correctement
  security.unprivilegedUsernsClone = true;

  # --- PKGS ---

  environment.systemPackages = with pkgs; [
    gnomeExtensions.dash-to-panel
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly  # utile pour mp3 notamment
    gst_all_1.gst-libav
    lact

    nix-tree
    compsize                            # utilitaire analyse Btrfs
    nix-tree                            # Analyse des paquets et dépendances
    ffmpeg
    git                                 # versionning, et interface avec repos en ligne
    hunspell                            # vérificateur orthographe, utilisé à l'échelle du système
    hunspellDicts.fr-any                # dictionaire français, utilisé à l'échelle du système
    hunspellDicts.fr-moderne            # dictionnaire francais, utilisé à l'échelle du système
    iw
    pciutils                            # Essentiel pour l'inventaire matériel
    python313                           # Version économiquee en espace disque (45 Mo)
    skopeo                              # manipulation des images bootc (création d'un fichier OCI local)
    tree                                # visualisation d'arborence (peut être redirigé ver sune sortie fichier texte)
    usbutils
    wget

    aria2                               # gestionnaire de téléchargement universel
    bat                                 # better cat. Visualisation esthetique
    btop                                # Version "esthétique" de htop (confort visuel)
    cosign                              # signature des images bootc (création d'un fichier OCI local)
    createrepo_c
    dialog                              # outil boites de dialogue scripts
    distrobox                           # Pour tests Silverblue/Debian/Arch sans polluer NixOS
    duf                                 # Visualisation rapide de l'espace disque
    earlyoom
    fd                                  # recherche
    fwupd                               # utilitaire de mise à jour de firmware
    fzf                                 # recherche intelligente
    glow                                # Lecture de documentation Markdown (supérieur à mdcat sur le rendu et la tolérance)
    just                                # Exécuteur de commandes de projet
    kiwix-tools                         # (3.0 MiB download, 12.6 MiB unpacked) wikipedia offline
    libva-utils                         # Permet de lancer 'vainfo' pour tester l'accélération vidéo
    libnotify                           # outil boites de dialogue scripts
    llama-cpp-vulkan                    # (10.6 MiB download, 79.9 MiB unpacked) Pour LLM optimisée GPU/iGPU
    lm_sensors                          # Surveillance des températures
    mc                                  # Gestionnaire de fichiers interactif
    mokutil                             # utilitaire interface secure boot
    msedit                              # éditeur de texte TUI, souris et menus, raccourcis clavier standards
    powertop                            # Vital pour optimiser la batterie
    ryzenadj
    s-tui                               # Monitoring CPU en temps réel
    shellcheck                          # contrôle de syntaxe scripts bash
    smartmontools                       # utilitaire analyse état SMART des disques
    stress-ng                           # Pour tester la stabilité du Ryzen
    tldr                                # astuces et conseil d'utilisation des logiciels
    tmux                                # multiplexeur de terminal
    yt-dlp                              # téléchargement de fichiers sur youtube (complet, juste audio, etc...)
    zenity                              # outil boites de dialogue scripts (GTK)
  ];
}
