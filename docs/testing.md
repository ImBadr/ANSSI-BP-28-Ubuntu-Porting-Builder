# Tester le projet

## Contrôles rapides

```bash
bash -n port-anssi.sh
docker build --check .
```

Ces contrôles détectent les erreurs de syntaxe du script et les erreurs élémentaires du Dockerfile.

## Tester l'image

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=master \
  -t anssi-port:test .

docker run --rm anssi-port:test list
docker run --rm anssi-port:test diagnose
```

## Tester un build complet sans écraser output/

```bash
rm -rf output-test
mkdir -p output-test
docker run --rm \
  -v "$PWD/output-test:/build/content/build" \
  anssi-port:test build

test -s output-test/ssg-ubuntu2604-ds.xml
docker run --rm \
  -v "$PWD/output-test:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap info /profiles/ssg-ubuntu2604-ds.xml'
```

## Tester plusieurs versions

Utilisez un dossier et un tag d'image séparés pour chaque produit :

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2204 \
  --build-arg TARGET_REF=<tag-ou-commit> \
  -t anssi-port:ubuntu2204 .

docker run --rm \
  -v "$PWD/output-ubuntu2204:/build/content/build" \
  anssi-port:ubuntu2204 build
```

## Critères de réussite

Un test de build est réussi si :

- l'image se construit sans erreur;
- `list` retourne les produits du checkout;
- `diagnose` se termine correctement;
- le datastream XML existe et n'est pas vide;
- `oscap info` lit le datastream et affiche les profils;
- un scan sur une cible correspondante produit un rapport XML et HTML.

Un résultat `fail` pendant un scan n'est pas un échec du build. Il indique une non-conformité de la machine scannée. Le builder et le scanner sont deux exécutions séparées : le premier conteneur produit les fichiers, le second les consomme.
