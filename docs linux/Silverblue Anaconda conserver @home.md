# Blivet (Anaconda) : Montage Btrfs Fedora Silverblue

Pour réinstaller ou configurer Fedora Silverblue dans Blivet (Anaconda) en conservant votre sous-volume home, la configuration exacte des sous-volumes Btrfs est la suivante :

| Sous-volume Btrfs | Point de montage | Action dans Blivet |
| -------- | --------- | ---------- |
| root     | /         | Supprimer et recréer|
| home | /var/home | Conserver |


Points d'attention spécifiques à Silverblue :

- Lien symbolique : Dans Fedora Silverblue (rpm-ostree), /home est un lien symbolique vers /var/home. Assurez-vous d'attribuer le point de montage /var/home au sous-volume home (et non /home).

- Autres partitions à ne pas oublier :

 * /boot (ext4) : Point de montage /boot , formater reformaté.

 * /boot/efi (FAT32) : Point de montage /boot/efi , à conserver si vous gardez un dual-boot, ou à reformatter.
