##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, lib, ... }:

let
  # On défini l'utilisateur sans avoir à le nommer
  normalUsers = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);

  # On défini le contenu du fichier de config que l'on veut générer pour newsboat
  newsboatUrlsSeed = pkgs.writeText "newsboat-urls-seed" ''
    "https://www.gamingonlinux.com/article_rss.php" "gaming" "linux"
    "https://www.linuxjournal.com/node/feed" "tech" "linux"
  '';
in
{
  # systemd créera le dossier avec les bonnes permissions, s'il n'existe pas déjà
  systemd.tmpfiles.rules = lib.concatMap (u: [
    "d ${u.home}/.newsboat 0750 ${u.name} users - -"
  ]) normalUsers;

  # un script systemd s'exécutera a chaque rebuild pour écrire le fichier de config newsboat
  # * si un fichier existe déjà, il ne sera pas écrasé mais sauvegardé avec sa date.
  system.activationScripts.newsboatUrlsSeed = {
    text = lib.concatMapStringsSep "\n" (u: ''
      target="${u.home}/.newsboat/urls"
      seed="${newsboatUrlsSeed}"
      if [ -e "$target" ] && ! ${pkgs.diffutils}/bin/cmp -s "$target" "$seed"; then
        cp -a "$target" "$target.backup-$(date +%Y%m%d-%H%M%S)"
      fi
      cp "$seed" "$target"
      chown ${u.name}:users "$target"
      chmod 0644 "$target"
    '') normalUsers;
    deps = [ "users" ];
  };
}
