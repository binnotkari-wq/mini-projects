# NIXOS = SILVERBLUE

**Objectif** : 

- produire un système nixos et un système silverblue ayant les mêmes fonctionnalités
- épuré et optimisé
- contient le nécessaire CLI à sa bonne exploitation
- plateforme de lancement des logiciels GUI qui seront à installer en flatpaks

> Les logigiels CLI supplémentaires : distrobox. Pas brew, celui-ci n'étant pas comptaible avec Nixos. Les configs de distrobox seront partagées sur github, pour être réutilisées librement.


## 📋 Sommaire

- [Brainstorm](#Brainstorm)
- [Logiciels à installer](#Logiciels-à-installer)
- [Tweaks à mettre en place](#Tweaks-à-mettre-en-place)
- [Drivers](#Drivers)
- [Process Nixos](#Process-Nixos)
  - [configuration.nix](#configuration.nix)
  - [softwares.nix](#softwares.nix)
  - [environment.nix](#environment.nix)
  - [tweaks.nix](#tweaks.nix)
  - [trimming.nix](#trimming.nix)
- [Process Silverblue](#Process-Silverblue)
  - [Containerfile+build.sh](#Containerfile+build.sh)
  - [softwares.sh](#softwares.sh)
  - [environment.nsh](#environment.sh)
  - [tweaks.sh](#tweaks.sh)
  - [trimming.sh](#trimming.sh)

Post-install



## Brainstorm]


### Steam

 Comparaison performances steam flatpak (silverblue) / natif (nixos)

Des tests seront à faire pour steam avec session gamescope+mangohud en flatpak.

### Firefox Video Fix

Firefox needs a little help with H.264 videos.

```bash
# Install the Cisco codec (it's free but weird licensing)
sudo dnf install -y openh264 gstreamer1-plugin-openh264 mozilla-openh264

# Enable the Cisco repo
sudo dnf config-manager --set-enabled fedora-cisco-openh264
sudo dnf update -y
```

> ⚠️ **Important**: Restart Firefox and check that the OpenH264 plugin is enabled in `about:addons`.

### bootc update

Voir :
https://bootc.dev/bootc/man/bootc-fetch-apply-updates.service.5.html

### Flatpak Auto-Updates

Injecter fichiers services systemd pour mises à jour auto (il faut que l'echec soit silencieux, on est pas forcement online : demander à Claude comment gérer l'echec)

You can keep your Flatpak apps up to date automatically. This setup updates your Flatpaks every 24 hours and is especially helpful if you disable GNOME Software on startup.

```bash
# Create the service unit
sudo tee /etc/systemd/system/flatpak-update.service > /dev/null <<'EOF'
[Unit]
Description=Update Flatpak apps automatically

[Service]
Type=oneshot
ExecStart=/usr/bin/flatpak update -y --noninteractive
EOF

# Create the timer unit
sudo tee /etc/systemd/system/flatpak-update.timer > /dev/null <<'EOF'
[Unit]
Description=Run Flatpak update every 24 hours
Wants=network-online.target
Requires=network-online.target
After=network-online.target

[Timer]
OnBootSec=120
OnUnitActiveSec=24h

[Install]
WantedBy=timers.target
EOF

# Reload systemd and enable the timer
sudo systemctl daemon-reload
sudo systemctl enable --now flatpak-update.timer

# Check the status to verify everything is working
sudo systemctl status flatpak-update.timer
```

> 🎯 **What this does**: Updates Flatpaks 2 minutes after boot, then every 24 hours. Set it and forget it!

---






Egalement, pré-personnalisation du système (firefox, shell, gnome, xdg).



## Logiciels à installer

Logiciels | Silverblue | Nixos 
----|----|----
compsize | intégré | pkgs
ffmpeg | intégré | pkgs
fwupd | intégré | pkgs
git | intégré | pkgs
gstreamer plugins (nautilus) | intégré | pkgs
hunspell | intégré | pkgs
hunspellDicts.fr-any | intégré | pkgs
hunspellDicts.fr-moderne | intégré | pkgs
iw | intégré | pkgs
libnotify | intégré | pkgs
mokutil | intégré | pkgs
pciutils | intégré | pkgs
podman | intégré | pkgs
python313 | intégré | pkgs
skopeo | intégré | pkgs
tracker/tinysparql | intégré | pkgs
tree | intégré | pkgs
usbutils | intégré | pkgs
wget | intégré | pkgs
nix-tree | sans objet | pkgs
gnome-shell-extension-dash-to-panel | softwares.sh | pkgs
aria2 | softwares.sh | pkgs
cosign | softwares.sh | pkgs
duf | softwares.sh | pkgs
earlyloom | softwares.sh | pkgs
powertop | softwares.sh | pkgs
lm_sensors | softwares.sh | pkgs
stress-ng | softwares.sh | pkgs
s-tui | softwares.sh | pkgs
libva-utils | softwares.sh | pkgs
msedit | softwares.sh | pkgs
shellcheck | softwares.sh | pkgs
bat | softwares.sh | pkgs
glow | softwares.sh | pkgs
dialog | softwares.sh | pkgs
zenity | softwares.sh | pkgs
kiwix-tools | softwares.sh | pkgs
llama-cpp-vulkan | softwares.sh | pkgs
distrobox | softwares.sh | pkgs
just | softwares.sh | pkgs
tmux | softwares.sh | pkgs
ryzenadj | softwares.sh | pkgs
smartmontools | softwares.sh | pkgs
yt-dlp | softwares.sh | pkgs
mc | softwares.sh | pkgs
btop | softwares.sh | pkgs
fd-find | softwares.sh | pkgs
fzf | softwares.sh | pkgs
tldr | softwares.sh | pkgs
zoxide | softwares.sh | pkgs


On intègre le repo flathub : flathub.flatpakrepo (ainsi qu'activation du service flatpak pour nixos)

Pour nixos, on installe LACT, qui ne peut fonctionner en flatpak (à cause du service systemd à mettre en place)

> Ne plus utiliser nerd-fonts.jetbrains-mono dans nixos. Utiles uniquement pour des logiciels TUI, concretement jamais utilisés.


Simulation sur un bootc silverblue 44 épuré : 

```
dnf5 install --downloadonly -y \
  gnome-shell-extension-dash-to-panel aria2 bat btop createrepo_c \
  dialog distrobox earlyoom fd-find fzf glow just kiwix-tools \
  libva-utils lm_sensors mc powertop s-tui shellcheck stress-ng \
  tldr tmux yt-dlp zenity \zoxide

Résumé de la transaction :
Installation :    114 paquets
La taille totale des paquets entrants est de 56 MiB. Un téléchargement de 56 MiB est nécessaire.
Après cette opération, 175 MiB supplémentaires seront utilisés (+150 MiB, -0 B).
L'opération ne fera que télécharger les paquets pour la transaction.
```

---

## Tweaks à mettre en place

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

Depuis Fedora Noble Setup, on recommande (mais c'est peut etre dejà partiellmeent en place d'origine ?) :


### AMD & Intel (The Easy Ones)

These usually just work, but let's make them work **better**.

#### Both AMD & Intel:

```bash
# Basic drivers and Vulkan support
sudo dnf install -y mesa-dri-drivers mesa-vulkan-drivers vulkan-loader mesa-libGLU
```

#### AMD Only:

```bash
# AMD video acceleration (makes videos smoother)
sudo dnf install -y mesa-va-drivers-freeworld mesa-vdpau-drivers-freeworld
```

#### Intel (Newer GPUs):

```bash
# Intel video acceleration (for newer Intel GPUs)
sudo dnf install -y intel-media-driver
```

#### Intel (Older GPUs):

```bash
# Intel video acceleration (for Grandfather Intel GPUs)
sudo dnf install -y libva-intel-driver
```

> ✅ **That's it!** AMD and Intel are usually plug-and-play.

---

### Hardware Acceleration

This makes video playback use your GPU instead of hammering your CPU.

```bash
# Install VA-API stuff
sudo dnf install -y ffmpeg-libs libva libva-utils
```






---

## Steam

Tests à faire pour voir si on peut lancer une session gamescope+mangohud en flatpak.

---

## Process Nixos

### configuration.nix
Système tel qu'installé par Calamares, dans /etc/nixos

### trimming.nix

On épure les apps gnome, de façon à n'avoir que les mêmes logiciels que Silerblue. La référence stripped-down est silverblue, qui ne propose que les applications suivantes :

- ptyxis
- nautilus
- paramètres
- firefox
- aide
- yelp
- disques
- moniteur système
- visite guidée (sera désinstallée de Silverblue)
- logiciels (sera désinstallée de Silverblue)
- contrôle parental

On supprime les services orca et speechd.

### tweaks.nix

Reprendre le contenu de performance_addons.nix + OS_options.nix

### softwares.nix

Reprendre le contenu selectionné de flatpak.nix, et des software_set_xxx

### environment.nix

Préférences système-wide.

Reprendre le contenu selectionné de xdg.nix, firefox.nix, shell.nix, gnome_dconf.nix

---

## Process Silverblue


L'image bootc = la plateforme de lancement, le socle minimal et non négociable (kernel, drivers, réseau, outils de base, ton check_system_health.sh). Elle change rarement, elle est testée, versionnée, reproductible bit à bit. Rôle : que la machine démarre et fonctionne, point.
Le repo flatpak local (create-usb) = la couche applicative, volontairement hors du cycle de vie de l'image. Rôle : que l'utilisateur ait le choix, au moment où il en a besoin, sans avoir à rebuild ou redéployer quoi que ce soit sur le socle.

Ça évite de maintenir un mapping figé entre versions d'image et sélection d'apps qui aurait fini par te forcer à rebuild l'image bootc à chaque fois que tu veux ajouter/retirer une appli — ce qui aurait cassé la promesse de stabilité du socle.


### trimming.sh

On supprime de Silverblue les packages non souhaités.

> Attention, malcontent (contrôle parental) est à conserver : sa suppression entraine la suppression de tou Gnome.

### tweaks.sh

### environment.sh

Préférences système-wide.

Placer les fichiers dans le dossier etc à injecter dans l'image bootc.
- préférences gnome
- paramétrage de firefox
- modèles de documents
- environnement CLI

> Ne pas intégrer la petite customisation qui est trop volatile pour être intégrée directement dans l'OS. Cela sera fait post-install, côté utilisateur. (laisser l'historisation). Enlever donc aussi les scripts d'update (pas mature, pas vraiment intégré dans un workflow pour l'instant)


 ## Post-install

### Give Your Computer a Name


Depuis Fedora Noble Setup :
This is purely cosmetic but makes you feel more at home. Pick something fun!

```bash
# Replace with whatever you want
sudo hostnamectl set-hostname hungry-beast
```