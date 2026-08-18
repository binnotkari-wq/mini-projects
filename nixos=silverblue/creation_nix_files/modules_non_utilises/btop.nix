{ config, lib, ... }:

# on récupère le chemin du dossier utilisateur et le nom de l'utilisateur qui a été déclaré comme un "isNormalUser".
# config.users.users est un attrset déjà entièrement résolu par NixOS à ce stade de l'évaluation,
# donc config.users.users.<nom>.home et .name sont disponibles.
# On évite donc de devoir importer des variables tout en conservant l'anonymat dans ce fichier .nix
let
  normalUsers = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);
in

{
  # btop va chercher sa configuration dans ~/.config/btop/btop.conf. On peut déclarer
  # sa configuration en créant le fichier .conf (création possible uniqueent dans /etc/)
  # puis en générant un lien à chaque démarrage
  # vers ~/.config/btop/btop.conf.

  # On déclare le fichier de configuration réel et immuable dans /etc
  environment.etc."btop/btop.conf".text = ''
    color_theme = "gruvbox_material_dark"
    theme_background = true
  '';

  # Lien symbolique de btop.conf vers ~/.config/
  systemd.tmpfiles.rules = lib.concatMap (u: [
    "d  ${u.home}/.config/btop 0755 ${u.name} users - -"
    "L+ ${u.home}/.config/btop/btop.conf - ${u.name} users - /etc/btop/btop.conf"
  ]) normalUsers;
}
