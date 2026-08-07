# Builds offline

Voici comment structurer un process 100% offline sur la partie base.

## 1. Récupérer et figer la base localement une fois pour toutes (en étant online)

```
bash
# Tirer l'image depuis GHCR et la stocker dans le storage podman local
sudo podman pull ghcr.io/binnotkari-wq/fedora_reference-bootc:latest
```

### L'exporter en tar vers /CARGO — ta copie de référence, indépendante du réseau et de GHCR

```
bash
sudo podman save -o /CARGO/images/fedora_reference-bootc-$(date +%Y%m%d).tar \
    ghcr.io/binnotkari-wq/fedora_reference-bootc:latest
```

Le suffixe date te permet de garder plusieurs versions de référence dans le temps (utile puisque ton workflow rebuild cette base une fois par mois — tu pourras comparer ou revenir en arrière).

## 2. Nouveau repo (ou dossier) pour les "forks" expérimentaux

Structure suggérée, séparée de fedora_reference-bootc :

```
ublue-bootc-experiments/
├── Containerfile
├── build_files/
│   └── tweaks.sh
└── README.md
```


Containerfile :

```
FROM localhost/fedora_reference-bootc:latest

COPY build_files/tweaks.sh /tmp/tweaks.sh
RUN chmod +x /tmp/tweaks.sh && /tmp/tweaks.sh && rm /tmp/tweaks.sh
```

Le FROM localhost/... pointe vers l'image déjà présente dans ton storage podman (chargée via podman load, voir étape 3) — aucune requête réseau vers GHCR n'est faite tant que le tag existe localement.

## 3. Charger la base depuis /CARGO sur une machine offline

Sur le X240 (ou n'importe quelle machine, même sans réseau) :

```
bash
sudo podman load -i /CARGO/images/fedora_reference-bootc-20260807.tar
sudo podman images   # vérifie que localhost/fedora_reference-bootc:latest apparaît
```

Puis tu buildes normalement :

```
bash
sudo podman build -t experiment-v1:latest .
```

Aucune connexion requise pour la base. La seule limite reste ce que tu ajoutes dans tweaks.sh — si tu fais dnf5 install -y tmux et que tmux n'a jamais été mis en cache, ça échouera offline (retour au §6 du kit).

## 4. Anticiper les paquets pour tes expérimentations offline

Puisque tu sais déjà que tu vas vouloir tester des ajouts (ton build.sh commenté le montre : tmux, podman.socket), le plus simple pendant que tu es online :

```
bash
# Pré-télécharger un paquet et ses dépendances sans l'installer
sudo dnf5 download --resolve --destdir=/CARGO/rpm-cache tmux
```

Puis dans ton Containerfile expérimental, dépôt local en fallback :

```
RUN dnf5 install -y --setopt=cachedir=/CARGO/rpm-cache tmux \
    || dnf5 install -y /CARGO/rpm-cache/tmux*.rpm
```

Ou plus simplement, un vrai petit dépôt local pointé par baseurl=file:///CARGO/rpm-cache — plus propre si tu accumules beaucoup de paquets au fil de tes tests.

## 5. Bon réflexe : ne jamais faire FROM ghcr.io/... directement dans tes forks expérimentaux

Si ton Containerfile expérimental référence FROM ghcr.io/binnotkari-wq/fedora_reference-bootc:latest (au lieu de localhost/...), Podman essaiera de vérifier/retirer l'image depuis le registre à chaque build, même si elle existe déjà en local — et ça cassera ton offline. Utilise systématiquement le tag localhost/ une fois l'image chargée, c'est le point le plus important à retenir de toute cette réponse.

Ça te donne un vrai "socle figé" versionné (le tar horodaté dans /CARGO), traçable jusqu'au commit GHCR d'origine, et une zone d'expérimentation complètement déconnectée du réseau tant que tu restes dans le périmètre de paquets déjà en cache.