# Construire et diagnostiquer

## Construire l'image

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=master \
  -t anssi-port .
```

Pour la reproductibilité, remplacez `master` par un tag ou un commit connu.

## Diagnostiquer avant le build

```bash
docker run --rm anssi-port list
docker run --rm anssi-port diagnose
```

`diagnose` vérifie que les sélections des profils source correspondent à des `rule.yml` présents dans le contenu partagé. Il ne prouve pas que la règle est applicable à l'OS cible.

## Générer le datastream

```bash
mkdir -p output
docker run --rm \
  -v "$PWD/output:/build/content/build" \
  anssi-port build
```

Fichiers attendus :

```text
output/ssg-ubuntu2604-ds.xml
output/ssg-ubuntu2604-xccdf.xml
output/logs/build-ubuntu2604.log
```

## Vérifications post-build

```bash
test -s output/ssg-ubuntu2604-ds.xml
oscap info output/ssg-ubuntu2604-ds.xml
```

Si le build échoue, lire le log :

```bash
less output/logs/build-ubuntu2604.log
```

Les erreurs `rule not found` signalent généralement une sélection inexistante. Les erreurs `no applicable check` ou des résultats `notapplicable` peuvent signaler une plateforme, un paquet, un fichier ou un contexte système absent.

## Changer de cible

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2204 \
  --build-arg TARGET_REF=<tag-ou-commit> \
  -t anssi-port:ubuntu2204 .
```

Utilisez une image distincte par cible afin d'éviter de confondre les datastreams et les profils.
