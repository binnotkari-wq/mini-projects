##############################################################################
# 100% agnostique, applicable à toute configuration
##############################################################################

{ config, pkgs, lib, ... }:

let
  # On défini l'utilisateur sans avoir à le nommer
  normalUsers = lib.filter (u: u.isNormalUser) (lib.attrValues config.users.users);

  # On défini le contenu du fichier de config que l'on veut générer
  pyradioCfgSeed = pkgs.writeText "pyradio-cfg-seed" ''
    log_titles = True
    auto_save_playlist = True
    enable_notifications = 0
    enable_clock = True
    theme = gruvbox_dark_by_sng
    use_transparency = True
    enable_mouse = True
  '';
in
{
  # systemd créera le dossier avec les bonnes permissions, s'il n'existe pas déjà
  systemd.tmpfiles.rules = lib.concatMap (u: [
    "d ${u.home}/.config/pyradio 0750 ${u.name} users - -"
  ]) normalUsers;

  # un script systemd s'exécutera a chaque rebuild pour écrire le fichier de config
  # * si un fichier existe déjà, il ne sera pas écrasé mais sauvegardé avec sa date.
  system.activationScripts.pyradioCfgSeed = {
    text = lib.concatMapStringsSep "\n" (u: ''
      target="${u.home}/.config/pyradio/config"
      seed="${pyradioCfgSeed}"
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
