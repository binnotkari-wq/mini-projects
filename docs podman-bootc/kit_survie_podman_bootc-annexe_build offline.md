# Builds offline

Voici comment structurer un process 100% offline sur la partie base.

## 1. Récupérer et figer l'image de base localement

Télécharger une fois pour toutes (en étant online) dans le storage podman local :

```
sudo podman pull quay.io/fedora-ostree-desktops/silverblue:44
```

L'exporter en tar vers /cargo — copie de référence, indépendante du réseau et de GHCR :

```
sudo podman save -o /cargo/local_cache/bootc/github/images/silverblue-44-$(date +%Y%m%d).tar \
    quay.io/fedora-ostree-desktops/silverblue:44
```

Le suffixe date te permet de garder plusieurs versions de référence dans le temps (utile puisque ton workflow rebuild cette base une fois par mois — tu pourras comparer ou revenir en arrière).

> pour une image custom, les tags n'existent pas. On les créé : sudo podman tag ghcr.io/binnotkari-wq/fedora_custom-bootc:latest localhost/fedora_custom-bootc:latest # par exemple

>Ensuite sudo podman images # vérifie que localhost/fedora_custom-bootc:latest apparaît


## 2. Constituer un repo RPM local

Puisque tu sais déjà que tu vas vouloir tester des ajouts (ton build.sh commenté le montre : tmux, podman.socket), le plus simple pendant que tu es online :


### Provisionner les rpm

Pré-télécharger les paquets et leurs dépendances, prévus en installation dans le container (à exécuter depuis un hote de base silverblue) :

```
bash
sudo dnf5 download --resolve \
  --setopt=install_weak_deps=False \
  --destdir=/home/benoit/CARGO/rpm-cache \
  gnome-shell-extension-dash-to-panel \
  distrobox \
  ... et caetera ...

# spécifique ryzenadj dispo sur COPR ublue
sudo dnf5 -y copr enable ublue-os/bazzite
sudo dnf5 download --resolve \
  --setopt=install_weak_deps=False \
  --destdir=/home/benoit/CARGO/rpm-cache \
  ryzenadj
sudo dnf5 -y copr disable ublue-os/bazzite
```

### Créer un repo rpm

Dans le cas où on execute depuis silverblue de base : à créer dans une toolbox depus silverblue puisque createrepo_c n'est pas installé dans silverblue :

```
bash
# Créer/entrer dans une toolbox (si tu n'en as pas déjà une)
toolbox create
toolbox enter

# À l'intérieur de la toolbox :
sudo dnf5 install -y createrepo_c
createrepo_c /home/benoit/CARGO/rpm-cache
```

### Vérification
On peut vérifier la création du repo rpm avec

```
bash
ls /home/benoit/CARGO/rpm-cache/repodata/
```

La présence de repomd.xml + les .xml.zst confirme que la structure est valide.


Et on peut faire une simulation d'installation de quelques uns des paquets locaux :

```
bash
sudo dnf5 --repofrompath=cargo-local,file:///home/benoit/CARGO/rpm-cache \
  install -y --setopt=install_weak_deps=False --assumeno \
  distrobox bat btop
```

## 3. Adaptations repo pour le mode offline


### Image source dans le Containerfile

podman ira chercher cette image dans son stockage local si pas de connection réseau. Elle est bien taguée ainsi avec podman pull. Aucune requête réseau n'est faite tant que le tag existe localement.

```
FROM localhost/quay.io/fedora-ostree-desktops/silverblue:44
```

### Repo rpm local dans softwares.sh

```
PACKAGES=(
  gnome-shell-extension-dash-to-panel
  earlyoom
  ...et caetera...
  )

if [ -d /run/rpm-cache ]; then
    printf '[cargo-local]\nname=CARGO local cache\nbaseurl=file:///run/rpm-cache\nenabled=1\ngpgcheck=0\npriority=1\n' \
        > /etc/yum.repos.d/cargo-local.repo
    dnf5 install -y --setopt=install_weak_deps=False --disablerepo='*' --enablerepo=cargo-local "${PACKAGES[@]}"
else
    dnf5 install -y --setopt=install_weak_deps=False "${PACKAGES[@]}"
fi

rm -f /etc/yum.repos.d/cargo-local.repo
```

## 4. Commande de build offline

### Charger la base depuis /cargo sur une machine offline

Que ce soit avant de builder l'OCI ou l'ISO

```
sudo podman load -i /cargo/local_cache/bootc/github/images/silverblue-44-$(date +%Y%m%d).tar
```

(Date indicative à adapter)

### Build container OCI

```
sudo podman build --network=none --no-cache \
  -v /cargo/local_cache/bootc/rpm-cache:/run/rpm-cache:ro,Z \
  -v /cargo/local_cache/bootc/bin-cache:/run/bin-cache:ro,Z \
  -t fedora_custom_bootc:latest .
```

Si on veut builder en allant chercher sur internet :
```
sudo podman build --no-cache -t fedora_custom_bootc:latest .
```

### Build image ISO

Lancer simplement buid-disk.sh qui est placé à la racine du projet git.
Script créé par Claude.

La construction de l'iso ne peut pas se faire en offline avec bootc-image-builder. Celui-ci construit un environnement de déploiement, et est prévu pour aller chercher en ligne dans les repos fedora, tous les rpm nécessaires à la construction de cet environnement d'installation.

#### *Fonctinnement de bootc-image-builder*

Il prend localhost/fedora_custom-bootc:latest que tu as construit, tel quel, comme un bloc figé (ton rootfs final, déjà buildé avec tous tes RPM/binaires custom) — il ne le modifie pas, ne le recompose pas, ne re-résout aucune dépendance dessus. C'est exactement le contenu que tu as validé en offline juste avant.

#### *D'où viennent alors les ~500 paquets ?*

Ils ne servent pas à composer ton système final — ils servent à construire l'environnement d'installation Anaconda lui-même, c'est-à-dire l'ISO amorçable qui va, une fois démarrée sur une machine, dérouler l'installateur graphique (partitionnement, choix langue, etc.) puis déployer ton image bootc dedans.

Concrètement, une ISO Anaconda contient deux choses bien distinctes :

Ton image bootc (fedora_custom-bootc) — le système qui sera réellement installé sur le disque cible. Ça, c'est déjà fait, figé, inchangé.
Un mini-environnement Linux autonome (noyau, initramfs, Anaconda + son interface graphique GTK, outils de partitionnement comme parted/blivet, pilotes de stockage/réseau génériques pour détecter le matériel de la machine cible, etc.) — c'est cet environnement qui nécessite les ~500 paquets, parce qu'il doit fonctionner de façon autonome sur n'importe quel matériel avant même que ton OS ne soit installé.

C'est un peu comme la différence entre "l'OS que tu vas utiliser" et "le installateur Windows/macOS qui tourne depuis une clé USB avant l'installation" — deux logiciels séparés, l'un ne contient pas nécessairement l'autre.

#### *Implication pratique pour toi*

Ça confirme la stratégie que je proposais : ton container (le vrai contenu utile, personnalisé, ce sur quoi tu passes le plus de temps) est déjà 100% reproductible offline — c'est acquis et validé. L'ISO Anaconda est un simple "emballage installateur" autour, qui change rarement de version d'une build à l'autre (l'installateur Fedora 44 reste le même installateur tant que tu ne changes pas de version majeure)




#### *Ce que fait réellement bootc-image-builder sous le capot*

Pour transformer une image de conteneur en ISO d'installation autonome, l'outil exécute plusieurs étapes gourmandes en processeur et en entrées/sorties disque :

Extraction et conversion du système de fichiers : il ne se contente pas de copier le conteneur. Il extrait toutes les couches (layers), reconstitue l'arborescence complète et formate une vraie partition disque virtuelle (dans votre cas, en btrfs).

Génération d'un initramfs dédié (Dracut) : il doit compiler un noyau et un système de démarrage temporaire (initramfs) capable de détecter le matériel de n'importe quel PC au boot de l'ISO. C'est l'étape qui génère souvent les avertissements grub2-probe que vous avez vus passer.

Création de l'image OSTree / Native Container : il prépare la structure ostree ou le magasin de conteneurs local qui sera directement copié sur le disque dur de la machine cible lors de l'installation.

Compression extrême (La partie la plus lente) : l'ISO utilise un système de fichiers compressé en lecture seule (SquashFS). La compression de plusieurs gigaoctets de données pour faire tenir l'OS et l'installeur Anaconda sur une ISO prend un temps considérable et sollicite énormément le processeur.

#### *Pourquoi c'est beaucoup plus long que podman build ?*

podman build ne fait qu'ajouter des couches légères et mettre à jour du texte/binaires dans un cache local.

bootc-image-builder fabrique une véritable image disque complète, initialise une table de partition (MBR/GPT), installe et configure GRUB, et compresse l'ensemble du système de fichiers.