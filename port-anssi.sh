#!/usr/bin/env bash
set -euo pipefail

CONTENT_DIR="/build/content"
PRODUCT="${TARGET_PRODUCT:-ubuntu2604}"
SRC_PRODUCT="${SOURCE_PRODUCT:-debian13}"
PROFILES_GLOB="${PROFILE_GLOB:-anssi_bp28_*.profile}"

cd "$CONTENT_DIR"

log() { echo -e "\033[1;34m[anssi-port]\033[0m $*"; }
warn() { echo -e "\033[1;33m[anssi-port]\033[0m $*"; }
err() { echo -e "\033[1;31m[anssi-port]\033[0m $*" >&2; }

check_product() {
    if [ ! -d "products/${PRODUCT}" ]; then
        err "Le produit '${PRODUCT}' n'existe pas dans products/."
        err "Produits disponibles :"
        ls products/
        exit 1
    fi
    if [ ! -d "products/${SRC_PRODUCT}" ]; then
        err "Le produit source '${SRC_PRODUCT}' n'existe pas (branche/tag trop ancien ?)."
        exit 1
    fi
}

copy_profiles() {
    log "Copie des profils ANSSI de ${SRC_PRODUCT} vers ${PRODUCT}..."
    mkdir -p "products/${PRODUCT}/profiles"
    shopt -s nullglob
    local files=(products/${SRC_PRODUCT}/profiles/${PROFILES_GLOB})
    if [ ${#files[@]} -eq 0 ]; then
        err "Aucun profil ANSSI trouvé dans products/${SRC_PRODUCT}/profiles/."
        err "Le nom des fichiers a peut-être changé en amont — vérifie manuellement."
        exit 1
    fi
    for f in "${files[@]}"; do
        base=$(basename "$f")
        if [ -f "products/${PRODUCT}/profiles/${base}" ]; then
            warn "  ${base} existe déjà dans ${PRODUCT}, non écrasé (supprime-le si tu veux le régénérer)."
        else
            cp "$f" "products/${PRODUCT}/profiles/${base}"
            log "  ${base} copié."
        fi
    done
}

do_build() {
    check_product
    copy_profiles
    mkdir -p "build/logs"
    log "Lancement du build pour ${PRODUCT} (ça peut prendre plusieurs minutes)..."
    if ! ./build_product "${PRODUCT}" 2>&1 | tee "build/logs/build-${PRODUCT}.log"; then
        err "Le build a échoué. Consulte build/logs/build-${PRODUCT}.log"
        err "Les erreurs de type 'rule not found' ou 'no applicable check' pointent vers des"
        err "règles ANSSI sans implémentation Ubuntu — lance '$0 diagnose' pour la liste."
        exit 1
    fi
    log "Build terminé. Datastream : build/ssg-${PRODUCT}-ds.xml"
    log "Profils ANSSI présents dans le résultat :"
    oscap info "build/ssg-${PRODUCT}-ds.xml" 2>/dev/null | grep -i anssi || warn "  Aucun profil ANSSI détecté dans le datastream final !"
}

do_diagnose() {
    check_product
    log "Comparaison des règles sélectionnées par les profils ANSSI (${SRC_PRODUCT}) avec le contenu disponible pour ${PRODUCT}..."
    for f in products/${SRC_PRODUCT}/profiles/${PROFILES_GLOB}; do
        pname=$(basename "$f" .profile)
        log "--- ${pname} ---"
        # Les profils générés sont JSON; le fallback conserve le support des anciens profils YAML.
        mapfile -t rules < <(python3 - "$f" <<'PY'
import json
import sys

try:
    with open(sys.argv[1], encoding="utf-8") as profile_file:
        profile = json.load(profile_file)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

for rule in profile.get("selections", []):
    if isinstance(rule, str) and rule.replace("_", "").isalnum():
        print(rule)
PY
        )
        if [ ${#rules[@]} -eq 0 ]; then
            mapfile -t rules < <(sed -nE 's/^\s*-\s*([a-zA-Z0-9_]+)\s*$/\1/p' "$f")
        fi
        for rule in "${rules[@]}"; do
            # Vérifie si la règle a un fichier rule.yml quelque part dans le contenu partagé
            if ! find linux_os -type f -path "*/${rule}/rule.yml" -print -quit 2>/dev/null | grep -q .; then
                echo "  [ABSENTE DU CONTENU PARTAGÉ] ${rule}"
            fi
        done
    done
    log "Les règles listées ci-dessus n'existent pas du tout dans le contenu partagé"
    log "(elles seront à retirer des .profile copiés, ou à implémenter)."
    log "Les règles NON listées existent mais peuvent quand même ne pas être 'platform'-compatibles Ubuntu :"
    log "vérifie le build log (build/logs/build-${PRODUCT}.log) pour les erreurs de type 'not applicable'."
}

do_list() {
    log "Produits disponibles dans ce checkout :"
    ls products/
}

case "${1:-build}" in
    build)    do_build ;;
    diagnose) do_diagnose ;;
    list)     do_list ;;
    shell)    exec bash ;;
    *)
        err "Commande inconnue: $1"
        err "Usage: docker run ... [build|diagnose|list|shell]"
        exit 1
        ;;
esac
