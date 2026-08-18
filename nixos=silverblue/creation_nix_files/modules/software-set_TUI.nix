##############################################################################
# 100% agnostique, applicable à toute configuration                          #
##############################################################################

{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    yazi                       # gestionnaire de fichiers TUI modulaire
    yaziPlugins.mount
    yaziPlugins.chmod
    yaziPlugins.compress
    yaziPlugins.full-border
    yaziPlugins.recycle-bin
    htop                        # Le classique immanquable
    mplayer                     # nécessaire à pyradio
    pyradio                     # radio web
    newsboat                    # lecteur RSS
    television                  # interface TUI à fd
    # superfile                 # gestionnaire de fichiers esthétique
    # ranger                    # gestionnaire de fichiers esthétique
    lynx                        # browser texte basique
    w3m                         # navigateur internet
    zellij                      # multiplexeur de terminal
    # tmux                      # multiplexeur de terminal
    md-tui                      # visualisateur Markdown. Le plus agréable. Permet d'editer, de rechercher...mais parfois n'interprète pas bien de md.
    musikcube                   # Lecteur mp3 esthétique
    # aerc                      # client mail
    gophertube                  # chercher, regarder et télécharger des vidéos depuis youtube
    browsh                      # browser texte esthétique
  ];
}
