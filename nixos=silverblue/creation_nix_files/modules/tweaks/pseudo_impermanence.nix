##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

# Permet de se rapprocher d'une impermanence, mais sans avoir à définir un schéma de partitionnement adapté
# ou une mise en place en pré-installation. On peut activer ou desactiver ce module quand on veut et quel
# que soit le schéma de partitions ou le type d'installation.
# !!! Ne pas activer si l'impermanence est déjà activé !!!

{ config, pkgs, vars, ... }:

{

# Les vars sont hérités de variables.nix. Si on n'utilise pas les variables, remplacer :
# - ${vars.machineid} par le résultat de : systemd-id128 new | tr -d '-'
# - ${vars.username} par le nom de l'utilisateur
# - vars.hashedPassword par le résultat de : mkpasswd lemotdepasse (par défaut ce hash sera généré avec l'algorythme yescrypt).

  # --- IDENTIFIANT MACHINE DECLARATIF ---
  # Pour que /etc/machine-id, /etc/shadow, /etc/passwd et /etc/group soient gérés déclarativement (initialement, ils sont créés de façon iméprative par Calamares).
  # A commenter si déjà géré en déclaratif dans un autre .nix.
  environment.etc."machine-id".text = "${vars.machineid}\n";
  users.users.${vars.username}.hashedPassword = vars.hashedPassword;
  users.mutableUsers = false;

  # Sécurité : données sudo en tmpfs, pas conservées sur disque ---
  fileSystems = {
    "/var/db/sudo" = { device = "none"; fsType = "tmpfs"; options = [ "defaults" "size=5M" "mode=700" ]; };
  };

  # RAM Disk natif pour /tmp ---
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "2G";

  # Journalisation Volatile (Propre et limitée) ---
  services.journald.extraConfig = ''
    Storage=volatile
    RuntimeMaxUse=100M
  '';

  # Règles d'hygiène automatique (Systemd-tmpfiles) ---
  # Configure systemd-tmpfiles pour supprimer ces éléments lors de l'arrêt du système
  systemd.tmpfiles.rules = [
    "R /var/lib/upower/* - - - - -"
    "R /var/cache/* - - - - -"
    "R /var/spool/cups/* - - - - -"
    "e /var/tmp 1777 root root 30d -"                                           # On nettoie /var/tmp s'il n'est pas touché pendant 30 jours
  ];

}
