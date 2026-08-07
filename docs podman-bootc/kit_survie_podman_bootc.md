# Kit de survie — Podman / Containers / bootc / Fedora Silverblue / skopeo

Contexte : `binnotkari-wq/ublue-bootc`, build local avec `sudo podman build`, objectif de comprendre le fonctionnement plutôt que d'accumuler des alias magiques.

---

## 1. Le concept clé : Podman n'a PAS un seul stockage

C'est la source de 90% des surprises ("mon image a disparu !").

Podman est **rootless-first**, ce qui veut dire que chaque UID système a son propre espace de stockage d'images/containers, complètement isolé des autres.

| Utilisateur | Storage réel |
|---|---|
| `benoit` (rootless, sans sudo) | `~/.local/share/containers/storage` |
| `root` (via `sudo podman ...`) | `/var/lib/containers/storage` |

**`sudo podman images` et `podman images` (sans sudo) interrogent deux disques durs virtuels différents.** Une image buildée avec `sudo` n'existera JAMAIS dans `podman images` sans sudo, et inversement. Ce n'est pas un bug, c'est le modèle de sécurité (isolation utilisateur, pas de fuite de privilèges entre users).

**Règle pratique :** choisis un mode par projet et reste-y. Pour `ublue-bootc`, comme bootc a de toute façon besoin de privilèges root à plusieurs étapes (voir §4), autant tout faire en `sudo podman` pour ce projet précis, et garder le rootless pour tes containers de dev/jeux/tests ponctuels.

Pour vérifier où tu es réellement :
```bash
podman info --format '{{.Store.GraphRoot}}'
sudo podman info --format '{{.Store.GraphRoot}}'
```

---

## 2. Vocabulaire — Image vs Container vs Layer

- **Image** : un artefact immuable, en lecture seule, empilement de *layers* (couches). C'est ton "modèle".
- **Container** : une instance *exécutable* d'une image, avec une couche en écriture par-dessus. Détruire le container ne touche pas à l'image.
- **Layer (couche)** : chaque instruction `RUN`, `COPY`, etc. dans ton `Containerfile` crée une couche. Elles sont mises en cache et réutilisées entre builds si rien n'a changé en amont (important pour comprendre pourquoi un rebuild est parfois instantané).
- **`<none>` / dangling image** : une couche intermédiaire qui a perdu son tag (souvent parce qu'un nouveau build a réutilisé le même tag `latest` et laissé l'ancienne couche orpheline). Sans danger à supprimer via `image prune`.

```bash
sudo podman images -a          # montre aussi les couches intermédiaires
sudo podman history <image>    # détail des layers d'une image donnée, avec taille par couche
```

---

## 3. Commandes essentielles (mode root, cohérent avec ton usage bootc)

### Lister / inspecter
```bash
sudo podman images                 # images taggées
sudo podman images -a              # + couches intermédiaires
sudo podman ps -a                  # containers, même arrêtés
sudo podman system df              # résumé espace disque
sudo podman system df -v           # détail par image/container/volume
sudo podman inspect <image|id>     # métadonnées complètes JSON
```

### Supprimer
```bash
sudo podman rmi <image_id_ou_tag>       # une image précise
sudo podman rmi -f <image_id>           # forcer si un container l'utilise encore
sudo podman rm <container_id>           # un container arrêté
```

### Purger
```bash
sudo podman container prune             # containers arrêtés
sudo podman image prune                 # images dangling (<none>) uniquement
sudo podman image prune -a              # + images non utilisées par aucun container
sudo podman system prune                # combo : containers arrêtés + réseaux + dangling + cache build
sudo podman system prune -a --volumes   # radical, inclut volumes non attachés — vérifie volume ls avant
```

### Build
```bash
sudo podman build -t <nom>:<tag> .
sudo podman build --no-cache -t <nom>:<tag> .   # ignore tout le cache de layers (build "propre")
sudo podman build --layers=false -t <nom>:<tag> .  # ne garde aucune couche intermédiaire (économise l'espace, mais rebuild plus lent)
```

---

## 4. bootc — la couche au-dessus de podman/OCI

**Le principe de bootc :** ton système Fedora (Silverblue, ou ta future image `ublue-bootc`) n'est pas installé "à la main" — il est **une image de container** (format OCI standard, la même chose que pour Docker/Podman classiques), que le système démarre directement en tant que rootfs, via `ostree` en dessous. C'est ce qui permet des mises à jour atomiques, des rollbacks, et un `Containerfile` comme unique source de vérité pour tout le système.

Chaîne de résolution : `Containerfile` → `podman build` → image OCI locale → push registre (GHCR) → `bootc switch` / `bootc upgrade` sur la machine cible → nouvelle "déploiement" ostree bootable, avec l'ancien conservé pour rollback.

### Pourquoi bootc a souvent besoin de root
- `bootc switch`, `bootc upgrade`, `bootc install` manipulent directement le rootfs/bootloader — opérations système par nature.
- Certains builds de `Containerfile` (notamment ceux d'Universal Blue) font des opérations de type `chown`/`setfacl` en dehors du mapping UID limité du mode rootless → root simplifie, même si ce n'est pas toujours strictement obligatoire.

### Commandes bootc utiles (sur la machine qui tourne l'image)
```bash
sudo bootc status                          # image actuelle + déploiements disponibles (= ton bstatus)
sudo bootc upgrade                         # tire la dernière version du même tag, staged (pas de reboot auto)
sudo bootc switch <registre>/<image>:<tag> # change carrément d'image de référence
sudo bootc rollback                        # revient au déploiement précédent
```

### Relation avec Fedora Silverblue
Silverblue est l'OS "de référence" ostree/immutable de Fedora, historiquement géré par `rpm-ostree` (commandes `rpm-ostree install`, `rpm-ostree override remove`, etc., overlay RPM par-dessus une base ostree).

bootc est le **successeur conceptuel** : au lieu de gérer des overlays RPM sur un ostree existant, tu redéfinis *l'image de base elle-même* via un `Containerfile` classique (`dnf5 install`, `dnf5 remove`, `COPY`, etc.), et bootc la déploie comme un ostree. Universal Blue (dont dérive `ublue-bootc`) est justement construit sur ce modèle : `dnf5` est la commande moderne à utiliser dans le `Containerfile`, `rpm-ostree override remove` est l'ancienne convention Silverblue-only qu'on n'utilise plus dans ce contexte.

En résumé :
- **Silverblue classique** = ostree + rpm-ostree, tu modifies le système en overlay après coup.
- **bootc / ublue-bootc** = ostree + image OCI buildée via podman, tu modifies le système *avant*, dans le `Containerfile`, et tu redéploies l'image entière.

---

## 5. skopeo — inspecter/déplacer des images SANS les exécuter

`skopeo` travaille au niveau du registre/format OCI pur, sans passer par un storage podman local complet. Utile pour inspecter une image distante ou la copier entre deux "transports" (registre, fichier local, storage podman/docker).

```bash
# Inspecter les métadonnées d'une image distante sans la télécharger entièrement
skopeo inspect docker://ghcr.io/binnotkari-wq/ublue-bootc:latest

# Copier une image du storage podman vers un fichier OCI local (pour bootc switch --transport oci)
skopeo copy containers-storage:localhost/fedora_reference-bootc:latest oci:/chemin/vers/dossier:latest

# Copier depuis un registre vers le storage local
skopeo copy docker://ghcr.io/binnotkari-wq/ublue-bootc:latest containers-storage:localhost/ublue-bootc:latest
```

Cas d'usage concret pour toi : builder localement avec podman, puis utiliser `skopeo copy` + `bootc switch --transport oci` pour tester une image *sans* la pousser sur GHCR — exactement le pipeline que tu avais commencé à explorer.

---

## 6. Fonctionner OFFLINE — cache dnf5 et limites réelles

### Ce qui est vrai
Une fois offline, `dnf5 install <nouveau paquet>` dans ton `Containerfile` échouera si le paquet (et ses dépendances) n'a jamais été téléchargé.

### Le cache qui peut te sauver
`dnf5`/`dnf` maintiennent un cache local des métadonnées de dépôts et des `.rpm` téléchargés, typiquement dans :
```
/var/cache/libdnf5/     (dnf5)
/var/cache/dnf/         (dnf legacy, encore présent sur certains setups)
```

**MAIS attention au contexte build container :** par défaut, un build podman classique (`RUN dnf5 install ...`) démarre chaque `RUN` dans un environnement où ce cache n'est PAS automatiquement persistant entre deux builds différents, sauf si :

1. **Tu utilises un cache mount BuildKit-style** (Podman supporte `--mount=type=cache` depuis les versions récentes) :
```dockerfile
RUN --mount=type=cache,target=/var/cache/libdnf5 \
    dnf5 install -y <paquet>
```
Ça persiste le cache RPM **entre builds successifs sur la même machine**, même si le container final ne le contient pas (le cache mount n'est jamais copié dans l'image finale — c'est exactement pour ça que tu avais conclu que `rm -rf /usr/etc` était le seul nettoyage manuel nécessaire, le reste étant déjà géré par les mounts).

2. **Le cache existe uniquement s'il a été peuplé AVANT de couper le réseau.** Si tu n'as jamais buildé (donc jamais téléchargé) tel paquet en étant online, il n'existera nulle part offline, cache ou pas.

### Vérifier ce que tu as en cache actuellement
```bash
sudo du -sh /var/cache/libdnf5/* 2>/dev/null
sudo find /var/cache/libdnf5 -name "*.rpm" | wc -l
```

### Stratégie robuste pour du offline fiable
Si tu veux vraiment pouvoir rebuilder hors ligne (chantier, X240 sans réseau) :
- **Option A — mirroir RPM local sur `/CARGO`** : télécharger à l'avance (`dnf5 download` ou `dnf5 reposync`) les paquets nécessaires vers `/CARGO/rpm-cache/`, puis pointer un dépôt `dnf5` local dessus (`baseurl=file:///CARGO/rpm-cache`) dans le `Containerfile`.
- **Option B — builder l'image en amont (online) et la stocker/exporter** : `podman save` ou `skopeo copy ... oci:` vers `/CARGO`, pour avoir une image finale prête à déployer offline même sans jamais rebuilder sur place.
```bash
sudo podman save -o /CARGO/images/ublue-bootc-latest.tar localhost/fedora_reference-bootc:latest
# puis ailleurs, offline :
sudo podman load -i /CARGO/images/ublue-bootc-latest.tar
```
- **Option C — cache mount persistant explicite** : forcer le cache mount à pointer vers un dossier durable plutôt que le cache éphémère de build, pour être sûr qu'il survit entre sessions même sur une machine reformatée.

**En résumé pour toi :** oui il y a un fallback (cache dnf5 + cache mounts BuildKit), mais il ne fonctionne QUE pour les paquets déjà rencontrés en ligne, et n'est fiable dans la durée que si tu le rends explicite (Option A ou B) plutôt que de compter sur le cache par défaut qui peut être purgé.

---

## 7. Pièges fréquents — check-list rapide

| Symptôme | Cause probable | Vérification |
|---|---|---|
| `podman images` ne montre pas mon image | Build fait avec `sudo`, lecture sans `sudo` (ou l'inverse) | `sudo podman images` vs `podman images` |
| Rebuild instantané alors que j'ai changé un `RUN` | Cache de layer réutilisé car une étape *antérieure* dans le Containerfile n'a pas changé | `--no-cache` pour forcer |
| Erreur cosign `invalid pem block` | Secret mal placé (Environment au lieu de Repository) | déjà résolu dans ton cas — vérifier Settings > Secrets > Repository |
| Image énorme malgré peu de paquets | Couches intermédiaires accumulées (`<none>`), pas de nettoyage `/usr/etc` etc. | `podman history`, `image prune -a` |
| `dnf5 install` échoue en offline sur un paquet "déjà utilisé avant" | Cache jamais peuplé pour CE paquet précis, ou cache purgé entre-temps | `find /var/cache/libdnf5 -name "*<paquet>*"` |
| Build échoue en CI mais marche en local | Storage/cache local (root) non reproduit dans l'environnement CI (toujours "propre") | Normal — la CI part toujours d'un cache vide, sauf cache GitHub Actions configuré explicitement |

---

## 8. Pense-bête des transports skopeo/podman (pour éviter de confondre)

| Préfixe transport | Signifie |
|---|---|
| `containers-storage:` | Le storage local podman (root ou rootless selon contexte) |
| `docker://` | Un registre distant (malgré le nom, fonctionne pour n'importe quel registre OCI : GHCR, Docker Hub, Quay...) |
| `oci:` | Un dossier local au format OCI brut (pas dans le storage podman, juste des fichiers) |
| `docker-archive:` / `oci-archive:` | Un fichier `.tar` unique (portable, exportable sur clé USB, `/CARGO`, etc.) |

---

*Généré pour accompagner la montée en compétence sur `binnotkari-wq/ublue-bootc` — à garder à côté du `Containerfile` et du `build.sh`.*