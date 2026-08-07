#!/usr/bin/env bash
#
# fork-init.sh — Workflow d'expérimentation offline sur une base bootc figée
#
# Principe :
#   1. Charger la dernière image de référence (.tar) depuis /CARGO/images
#   2. Builder le Containerfile local (FROM localhost/... obligatoire)
#   3. Tagger le résultat avec un horodatage, pour garder l'historique des essais
#
# Usage :
#   ./fork-init.sh                          # base la plus récente, tag auto
#   ./fork-init.sh --tar <fichier.tar>       # forcer une base précise
#   ./fork-init.sh --name mon-experiment     # nom de l'image finale
#   ./fork-init.sh --no-cache                # rebuild sans cache de layers
#
#
# Place le script à la racine de ton dossier d'expérimentation (celui avec ton Containerfile du
# type FROM localhost/fedora_reference-bootc:latest), rends-le 
# exécutable (déjà fait dans le fichier livré), et lance-le.

# Une chose à vérifier avant ta première utilisation réelle : le nom du tag à l'intérieur du tar
# peut différer selon comment tu l'as généré. Fais un premier essai avec sudo podman load -i <ton_tar>
# suivi de sudo podman images, pour confirmer que le tag chargé correspond bien exactement à
# localhost/fedora_reference-bootc:latest — sinon il faudra ajuster BASE_IMAGE_LOCAL en haut du script.



set -euo pipefail

# --- Configuration ---
CARGO_IMAGES_DIR="/CARGO/images"
BASE_IMAGE_LOCAL="localhost/fedora_reference-bootc:latest"
EXPERIMENT_NAME="experiment"
CONTAINERFILE="./Containerfile"
NO_CACHE=""
TAR_OVERRIDE=""

# --- Parsing des arguments ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --tar)
            TAR_OVERRIDE="$2"
            shift 2
            ;;
        --name)
            EXPERIMENT_NAME="$2"
            shift 2
            ;;
        --containerfile)
            CONTAINERFILE="$2"
            shift 2
            ;;
        --no-cache)
            NO_CACHE="--no-cache"
            shift
            ;;
        -h|--help)
            grep '^#' "$0" | sed 's/^#//'
            exit 0
            ;;
        *)
            echo "Argument inconnu : $1" >&2
            exit 1
            ;;
    esac
done

# --- Vérifications préalables ---
if [[ ! -f "$CONTAINERFILE" ]]; then
    echo "Erreur : $CONTAINERFILE introuvable dans le dossier courant." >&2
    exit 1
fi

if ! grep -q "^FROM localhost/" "$CONTAINERFILE"; then
    echo "Attention : $CONTAINERFILE ne référence pas une image 'localhost/'." >&2
    echo "Un FROM pointant vers un registre distant (ghcr.io/...) déclenchera" >&2
    echo "une vérification réseau à chaque build et cassera le mode offline." >&2
    read -rp "Continuer quand même ? [o/N] " reponse
    [[ "$reponse" =~ ^[oO]$ ]] || exit 1
fi

# --- Sélection du fichier tar de référence ---
if [[ -n "$TAR_OVERRIDE" ]]; then
    TAR_FILE="$TAR_OVERRIDE"
else
    if [[ ! -d "$CARGO_IMAGES_DIR" ]]; then
        echo "Erreur : $CARGO_IMAGES_DIR introuvable." >&2
        exit 1
    fi
    TAR_FILE=$(find "$CARGO_IMAGES_DIR" -maxdepth 1 -name "fedora_reference-bootc-*.tar" \
        -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
    if [[ -z "$TAR_FILE" ]]; then
        echo "Erreur : aucune image de référence trouvée dans $CARGO_IMAGES_DIR" >&2
        echo "Attendu : fedora_reference-bootc-AAAAMMJJ.tar" >&2
        exit 1
    fi
fi

echo "==> Base de référence sélectionnée : $TAR_FILE"

# --- Chargement dans le storage podman (idempotent, aucun accès réseau) ---
echo "==> Chargement de l'image dans le storage local (podman load)..."
sudo podman load -i "$TAR_FILE"

if ! sudo podman image exists "$BASE_IMAGE_LOCAL"; then
    echo "Erreur : après chargement, $BASE_IMAGE_LOCAL est introuvable." >&2
    echo "Vérifie le tag présent dans le tar avec : sudo podman load -i $TAR_FILE" >&2
    exit 1
fi

# --- Build de l'expérimentation ---
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TAG="${EXPERIMENT_NAME}:${TIMESTAMP}"

echo "==> Build de l'expérimentation : $TAG"
# shellcheck disable=SC2086
sudo podman build $NO_CACHE -t "$TAG" -f "$CONTAINERFILE" .

# On tague aussi 'latest' pour l'expérimentation en cours, pratique pour itérer vite
sudo podman tag "$TAG" "${EXPERIMENT_NAME}:latest"

echo ""
echo "==> Terminé."
echo "    Image buildée : $TAG"
echo "    Alias         : ${EXPERIMENT_NAME}:latest"
echo ""
echo "    Historique des essais pour ce fork :"
sudo podman images --filter "reference=${EXPERIMENT_NAME}" \
    --format "table {{.Repository}}\t{{.Tag}}\t{{.Created}}\t{{.Size}}"
