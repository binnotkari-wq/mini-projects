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

## 4. Commande podman offline

### Charger la base depuis /cargo sur une machine offline

Date indicative à adapter

```
sudo podman load -i /cargo/local_cache/bootc/github/images/
```


### Build container OCI

```
sudo podman build --network=none --no-cache \
  -v /cargo/local_cache/bootc/rpm-cache:/run/rpm-cache:ro,Z \
  -v /cargo/local_cache/bootc/bin-cache:/run/bin-cache:ro,Z \
  -t fedora_custom_bootc:latest .
```


### Build image ISO







## 5. Bon réflexe : ne jamais faire FROM ghcr.io/... directement dans tes forks expérimentaux

Si ton Containerfile expérimental référence FROM ghcr.io/binnotkari-wq/fedora_reference-bootc:latest (au lieu de localhost/...), Podman essaiera de vérifier/retirer l'image depuis le registre à chaque build, même si elle existe déjà en local — et ça cassera ton offline. Utilise systématiquement le tag localhost/ une fois l'image chargée, c'est le point le plus important à retenir de toute cette réponse.
