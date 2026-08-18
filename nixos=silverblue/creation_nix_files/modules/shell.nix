##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, ... }:

{
  programs.bash.enable = true;

  # ── Alias (system-wide, /etc/bashrc) ────────────────────────────────────
  environment.shellAliases = {
    d       = "du -h --max-depth=0";
    ll      = "ls -l";
    nrs     = "sudo nixos-rebuild switch";
    nrb     = "sudo nixos-rebuild boot";
    nrt     = "sudo nixos-rebuild test";
    garbage = "nix-collect-garbage -d";
    bkp     = "$HOME/Git/scripts/backup.sh";
    bh      = "$HOME/Git/scripts/bash-history-export.sh";
    gs      = "$HOME/Git/scripts/git-sync.sh";
    gemma   = ''llama-cli --model "/cargo/local_cache/LLM/gemma-3-4b-it-Q8_0.gguf" --conversation --system-prompt "Tu es un assistant compréhensif pour la vie quotidienne : ménage, jardin, travaux, mécanique." --no-mmap --ctx-size 4096'';
    qwen    = ''llama-cli --model "/cargo/local_cache/LLM/Qwen2.5-Coder-3B-Instruct-abliterated-Q4_K_M.gguf" --conversation --system-prompt "Tu es un assistant concis en ingénierie des systèmes linux, scripting, développement." --no-mmap --ctx-size 4096'';
    llama   = ''llama-cli --model "/cargo/local_cache/LLM/Llama-3.2-3B-Instruct-Q4_K_M.gguf" --conversation --system-prompt "Tu es un assistant personnel pour m'aider à explorer de nouveaux concepts." --no-mmap --ctx-size 4096'';
  };

  # ── Historique (variables d'environnement globales) ─────────────────────
  environment.variables = {
    HISTSIZE     = "100000";
    HISTFILESIZE = "100000";
    HISTTIMEFORMAT = "%s ";
  };

  # ── Injection dans .bashrc / .profile pour TOUS les utilisateurs ────────
  # NB: interactiveShellInit -> équivalent de bashrcExtra
  #     loginShellInit       -> équivalent de profileExtra
  environment.interactiveShellInit = ''
    export PATH="$HOME/Git/scripts:$PATH"

    # Prompt façon GNOME Terminal
    PS1='\[\e[01;32m\][\u@\h\[\e[00m\]:\[\e[01;34m\]\w\[\e[01;32m\]]\$\[\e[00m\] '

    # Historique : append immédiat
    shopt -s histappend
    echo "# SESSION $(date +%s)" >> "$HISTFILE"
    PROMPT_COMMAND="history -a''${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

    # Message de bienvenue NixOS (shell interactif non-login)
    if [[ $- == *i* ]]; then
      bash /etc/scripts/nixos-welcome.sh
    fi
  '';

  environment.loginShellInit = ''
    if [[ $- == *i* ]]; then
      bash /etc/scripts/nixos-welcome.sh
    fi
  '';

  environment.etc."scripts/nixos-welcome.sh".source = pkgs.writeShellScript "nixos-welcome" ''
    #!/usr/bin/env bash

    RESET='\033[0m'
    BOLD='\033[1m'
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    PURPLE='\033[0;35m'
    GRAY='\033[0;90m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'

    echo ""
    echo -e "''${PURPLE}⬡''${RESET}  ''${BOLD}''${BLUE}Bienvenue sur NixOS''${RESET}  ''${GRAY}— $HOSTNAME''${RESET}"
    echo ""

    echo -e "''${YELLOW}▸ REBUILD & MISE À JOUR''${RESET}"
    echo -e "  ''${CYAN}sudo nixos-rebuild switch''${RESET}           ''${GRAY}# Applique la config et active immédiatement''${RESET}"
    echo -e "  ''${CYAN}sudo nixos-rebuild boot''${RESET}             ''${GRAY}# Applique au prochain redémarrage''${RESET}"
    echo -e "  ''${CYAN}sudo nixos-rebuild test''${RESET}             ''${GRAY}# Teste sans changer le bootloader''${RESET}"
    echo ""

    echo -e "''${YELLOW}▸ NIX STORE & PAQUETS''${RESET}"
    echo -e "  ''${CYAN}nix-shell -p <paquet>''${RESET}               ''${GRAY}# Shell temporaire avec le paquet''${RESET}"
    echo -e "  ''${CYAN}nix-collect-garbage -d''${RESET}              ''${GRAY}# Supprime les générations et nettoie''${RESET}"
    echo -e "  ''${CYAN}du -sh /nix/store''${RESET}                   ''${GRAY}# Taille occupée par le store (compression zstd ignorée)''${RESET}"
    echo ""

    echo -e "''${YELLOW}▸ GÉNÉRATIONS & ROLLBACK''${RESET}"
    echo -e "  ''${CYAN}nixos-rebuild list-generations''${RESET}      ''${GRAY}# Liste toutes les générations''${RESET}"
    echo -e "  ''${CYAN}nix-env -p /nix/var/nix/profiles/system --delete-generations 1 2 3 5''${RESET} ''${GRAY}# Supprime ces générations''${RESET}"
    echo -e "  ''${RED}sudo nixos-rebuild switch --rollback''${RESET} ''${GRAY}# Revenir à la génération précédente''${RESET}"
    echo ""

    echo -e "''${YELLOW}▸ DIAGNOSTIC''${RESET}"
    echo -e "  ''${CYAN}journalctl -b -p err''${RESET}                ''${GRAY}# Erreurs depuis le dernier boot''${RESET}"
    echo -e "  ''${CYAN}systemctl --failed''${RESET}                  ''${GRAY}# Services en échec''${RESET}"
    echo -e "  ''${CYAN}nix-store --verify --check-contents''${RESET} ''${GRAY}# Vérifie l'intégrité du store''${RESET}"
    echo ""

    echo -e "''${YELLOW}▸ UTILES''${RESET}"
    echo -e "  ''${CYAN}alias''${RESET}                               ''${GRAY}# Liste les commandes personnalisées''${RESET}"
    echo -e "  ''${CYAN}sudo compsize /nix''${RESET}                  ''${GRAY}# Taille occupée par l'OS (tenant compte de la compression zstd)''${RESET}"
    echo ""
  '';
}
