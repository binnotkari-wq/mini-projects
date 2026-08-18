# Fichier généré automatiquement par cargo.sh — propre à cette machine,
# ne pas versionner (voir .gitignore du dépôt).
# Device codé en dur (plutôt que via vars.luksUuid) pour ne pas dépendre de
# variables.nix dans un fichier qui n'existe que localement.
{ config, pkgs, ... }:
{
  fileSystems."/cargo" =
    { device = "/dev/mapper/luks-685f8dd8-fd47-4b10-8a80-28b87ac580b3";
      fsType = "btrfs";
      options = [ "subvol=cargo" "noatime" "compress=zstd" "ssd" "discard=async" ];
    };
}
