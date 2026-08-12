# NIXOS = SILVERBLUE

> Voir Fedora Linux Noble Setup Guide, il y a des choses intéressantes à étudier.

> Impermanence sur Silverblue...possible ? Apres tout, il s'agit de dispositifs systemd pour mettre / en tmpfs et vider etc et var de tout éléments temporaire.

>Des tests seront à faire pour steam (session gamescope+mangohud en flatpak?)

**Objectif** : produire un système nixos et un système silverblue ayant les mêmes fonctionnalités.

L'OS doit être "stripped-down" et optimisé. Il contiendra les outils système nécessaires à sa bonne exploitation. Il consituera une plateforme de lancement des logiciels GUI qui seront en flatpaks.
Les logigiels CLI supplémentaires : soit par brew, soit par distrobox. Mais brew n'est pas compatible nixos. La méthode privilégiée sera donc distrobox, brew sera provisionné pour Silverblue au cas où. Les configs de distrobox seront partagées sur github, pour être réutilisées librement.

Facultatif : pré-personnalisation du système (firefox, shell, gnome, xdg).

La référence stripped-down est silverblue, qui ne propose que les applications suivantes :

- ptyxis
- nautilus
- paramètres
- firefox
- aide
- yelp
- disques
- moniteur système
- visite guidée (à désinstaller)
- logiciels (à désinstaller)
- contrôle parental (à désinstaller)

## Logiciels à installer

Logiciels | Silverblue | Nixos 
----|----|----
compsize | intégré | pkgs
git | intégré | pkgs
hunspell | intégré | pkgs
hunspellDicts.fr-any | intégré | pkgs
hunspellDicts.fr-moderne | intégré | pkgs
iw | intégré | pkgs
libnotify | intégré | pkgs
pciutils | intégré | pkgs
podman | intégré | pkgs
python313 | intégré | pkgs
skopeo | intégré | pkgs
tree | intégré | pkgs
usbutils | intégré | pkgs
wget | intégré | pkgs
nix-tree | sans objet | pkgs
powertop | softwares.sh | pkgs
lm_sensors | softwares.sh | pkgs
stress-ng | softwares.sh | pkgs
s-tui | softwares.sh | pkgs
libva-utils | softwares.sh | pkgs
aria2 | softwares.sh | pkgs
shellcheck | softwares.sh | pkgs
bat | softwares.sh | pkgs
glow | softwares.sh | pkgs
dialog | softwares.sh | pkgs
zenity | softwares.sh | pkgs
kiwix-tools | softwares.sh | pkgs
llama-cpp-vulkan | softwares.sh | pkgs
distrobox | softwares.sh | pkgs
just | softwares.sh | pkgs
yt-dlp | softwares.sh | pkgs
mc | softwares.sh | pkgs
btop | softwares.sh | pkgs
fd-find | softwares.sh | pkgs
fzf | softwares.sh | pkgs
tldr | softwares.sh | pkgs
zoxide | softwares.sh | pkgs
gnome-shell-extension-dash-to-panel | softwares.sh | pkgs

On intègre le repo flathub : flathub.flatpakrepo (ainsi qu'activation du service flatpak pour nixos)

Pour nixos, on installe LACT, qui ne peut fonctionner en flatpak (à cause du service systemd à mettre en place)

> Ne plus utiliser nerd-fonts.jetbrains-mono dans nixos. Utiles uniquement pour des logiciels TUI, concretement jamais utilisés.

---

## Optimisations à mettre en place

Optimisation | Silverblue | Nixos 
----|----|----
relatime | intégré | nix
gamemode | intégré | nix
fstrim.timer | intégré | nix
discard=async | intégré | nix (à déclarer sur LUKS et volumes btrfs)
ntsync | charger module | nix
swappiness | paramétrer | nix
zram zstd | passer de lzo-rle à zstd | nix
btrfs zstd 3 | passer de 1 à 3 | nix
earlyloom | installer | nix

---

## Options OS à mettre en place

Options | Silverblue | Nixos 
----|----|----
Sécurité | SELinux intégré | apparmor à déclarer
Boot graphique plymouth | intégré | à déclarer
bluetooth | intégré | à déclarer
vulkan | intégré | à déclarer
upower | intégré | à déclarer

---

## Drivers

Tests à faire sur Une système Silverblue installé pour faire état des lieux.

---

## Steam

Tests à faire pour voir si on peut lancer une session gamescope+mangohud en flatpak.

---

## Process Nixos

### configuration.nix
Système tel qu'installé par Calamares, dans /etc/nixos

### trimming.nix

On supprime tout autre logiciel gnome que  :

- ptyxis
- nautilus
- paramètres
- firefox
- aide
- yelp
- disques
- moniteur système


  services.gnome.core-apps.enable = false; # sans le bundle des apps

  environment.systemPackages = with pkgs; [ # mais on veut celles-ci, essentielles (et présente dans silverblue -> liste flatpaks identique)
    ptyxis
    nautilus
	gnome-control-center
	firefox
    gnome-user-docs
    yelp
    gnome-disk-utility
    gnome-system-monitor
  ];


On supprime les services orca et speechd.

### tweaks.nix

Reprendre le contenu de performance_addons.nix + OS_options.nix

### softwares.nix

Reprendre le contenu selectionné de flatpak.nix, et des software_set_xxx

### preferences.nix

Reprendre le contenu selectionné de xdg.nix, firefox.nix, shell.nix, gnome_dconf.nix

---

## Process Silverblue

### trimming.sh

On supprime de Silverblue :

- visite guidée
- logiciels
- contrôle parental
- orca
- speechd
- qt5 et qt6
- les extension gnome proposées par fedora
- les services non souhaités

### préférences et compte utilisateur

Placer les fichiers dans le dossier etc à injecter dans l'image bootc.
- préférences gnome
- paramétrage de firefox
- modèles de documents
- environnement CLI
