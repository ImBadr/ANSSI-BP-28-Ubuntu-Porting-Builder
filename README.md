# ANSSI-BP-028 pour Ubuntu — build automatisé

Ce Docker clone `ComplianceAsCode/content`, copie les profils ANSSI-BP-028
existants du produit source `debian13` vers le produit cible Ubuntu, puis build le
datastream SCAP résultant.

**Ce que ça automatise** : les étapes 1 à 4 de la procédure manuelle
(clone, copie des `.profile`, build, vérification que le profil apparaît
dans le datastream).

**Ce que ça n'automatise PAS** : le nettoyage des règles orphelines
(étape 5 de la procédure manuelle) — c'est-à-dire les règles ANSSI qui
n'ont pas d'implémentation Ubuntu et qui feront échouer ou fausser le
build. La commande `diagnose` t'aide à les repérer, mais l'arbitrage
(retirer la règle du profil, ou lui ajouter un `platform:
multi_platform_ubuntu`) reste manuel.

## Usage

Le fonctionnement tient en trois commandes :

1. construire l'image avec les paramètres;
2. lancer le conteneur builder, qui écrit le datastream dans `./output` puis
   s'arrête;
3. lancer un second conteneur Ubuntu qui monte le même dossier `./output`,
   récupère le datastream et exécute OpenSCAP.

`docker build` construit l'image. Le datastream est généré par
`docker run ... anssi-port build`.

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=master \
  -t anssi-port .

docker run --rm \
  -v "$PWD/output:/build/content/build" \
  anssi-port build                         # build complet

docker run --rm \
  -v "$PWD/output:/build/content/build" \
  anssi-port diagnose                      # règles absentes du contenu partagé

docker run --rm anssi-port list            # produits disponibles
docker run --rm -it anssi-port shell       # shell de diagnostic
```
## Fonctionnement

Le [Dockerfile](Dockerfile) :

1. installe les dépendances de build et OpenSCAP;
2. clone `ComplianceAsCode/content` à la référence demandée;
3. copie les profils `anssi_bp28_*.profile` du produit source;
4. construit le produit cible avec `build_product`;
5. écrit le datastream et les artefacts dans le volume monté.

Le [script de portage](port-anssi.sh) expose quatre commandes : `build`,
`diagnose`, `list` et `shell`.

## Prérequis

Pour construire le contenu :

- Docker Desktop ou Docker Engine;
- l'accès réseau à GitHub pendant le build, sauf si l'image est déjà en cache;
- environ quelques gigaoctets d'espace disque pour les sources et les artefacts.

Pour scanner une machine Ubuntu :

```bash
sudo apt update
sudo apt install -y openscap-scanner
```

## Démarrage rapide

Depuis la racine du projet :

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=master \
  -t anssi-port .
```

Lancer le build et conserver les résultats dans `./output/` :

```bash
mkdir -p output
docker run --rm \
  -v "$PWD/output:/build/content/build" \
  anssi-port build
```

Le datastream principal sera alors :

```text
output/ssg-ubuntu2604-ds.xml
```

Les logs seront disponibles dans :

```text
output/logs/build-ubuntu2604.log
```

## Arguments de build

| Argument | Défaut | Rôle |
| --- | --- | --- |
| `SOURCE_PRODUCT` | `debian13` | Produit contenant les profils ANSSI source |
| `TARGET_PRODUCT` | `ubuntu2604` | Produit ComplianceAsCode à construire |
| `TARGET_REF` | `master` | Branche, tag ou référence Git upstream |

Exemple pour Ubuntu 22.04 :

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2204 \
  --build-arg TARGET_REF=master \
  -t anssi-port:ubuntu2204 .
```

Pour un build reproductible, utilisez un tag ou un commit plutôt que
`master`.

## Commandes disponibles

Lister les produits présents dans le checkout upstream :

```bash
docker run --rm anssi-port list
```

Vérifier les règles sélectionnées par les profils source :

```bash
docker run --rm anssi-port diagnose
```

Ouvrir un shell dans l'environnement ComplianceAsCode :

```bash
docker run --rm -it anssi-port shell
```

Le shell est utile pour inspecter les profils et les règles, mais les
modifications faites sans volume de sources sont perdues à la sortie.

## Lancer un scan OpenSCAP

### 1. Vérifier le profil et le datastream

Après le build, vérifier le datastream dans le second conteneur :

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap info /profiles/ssg-ubuntu2604-ds.xml'
```

Le profil complet est généralement identifié par :

```text
xccdf_org.ssgproject.content_profile_anssi_bp28_enhanced
```

Les profils ANSSI disponibles sont normalement `minimal`, `intermediary`,
`high` et `enhanced`. Utilisez les identifiants affichés par `oscap info` si
la version upstream les a modifiés.

### 2. Scanner avec le second conteneur Ubuntu

Cette commande monte le même dossier `./output` que le builder :

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_anssi_bp28_enhanced \
    --results /profiles/results-anssi-enhanced.xml \
    --report /profiles/report-anssi-enhanced.html \
    /profiles/ssg-ubuntu2604-ds.xml'
```

Le conteneur scanner s'arrête lui aussi lorsque le scan est terminé. Les
rapports restent dans `./output/` grâce au même volume monté.

Pour Ubuntu 24.04, remplacez `ubuntu:26.04` par `ubuntu:24.04` et
`ubuntu2604` par `ubuntu2404`.

### 3. Tester une remédiation dans le second conteneur

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap xccdf eval \
    --profile xccdf_org.ssgproject.content_profile_anssi_bp28_minimal \
    --remediate \
    --results /profiles/results-remediate.xml \
    --report /profiles/report-remediate.html \
    /profiles/ssg-ubuntu2604-ds.xml'
```

Cette remédiation modifie le second conteneur, pas l'ordinateur hôte. Avec
`--rm`, les modifications système du conteneur disparaissent à sa suppression;
les rapports restent dans `./output/`.

### 4. Scanner une vraie machine cible

Pour évaluer le système réel, copiez le datastream sur une VM ou une machine
Ubuntu correspondant au datastream, installez `openscap-scanner` sur cette
machine, puis lancez :

```bash
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_anssi_bp28_enhanced \
  --results results-anssi-enhanced.xml \
  --report report-anssi-enhanced.html \
  output/ssg-ubuntu2604-ds.xml
```

Pour le profil minimal :

```bash
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_anssi_bp28_minimal \
  --results results-anssi-minimal.xml \
  --report report-anssi-minimal.html \
  output/ssg-ubuntu2604-ds.xml
```

Consulter ensuite le rapport :

```bash
xdg-open report-anssi-enhanced.html
```

Sur macOS, le rapport peut être ouvert avec :

```bash
open report-anssi-enhanced.html
```

Ne lancez pas `--remediate` lors du premier test. Cette option modifie
directement la configuration de la machine.

### 5. Comprendre le code de sortie

OpenSCAP peut retourner un code différent de zéro lorsqu'une règle échoue.
Ce n'est pas nécessairement une erreur d'exécution. Les résultats doivent
être lus dans le rapport HTML ou le fichier XML :

- `pass` : la règle est satisfaite;
- `fail` : la règle est évaluée et n'est pas satisfaite;
- `notapplicable` : la plateforme, le paquet, le fichier ou le contexte ne
  permet pas d'appliquer la règle;
- `notselected` : la règle existe mais n'appartient pas au profil choisi;
- `error` : le contrôle n'a pas pu être exécuté correctement.

## Conteneur ou vraie machine ?

Un scan dans un conteneur est utile pour un test technique, mais il ne
représente pas une installation Ubuntu complète. Les règles liées au noyau,
GRUB, `/boot`, AppArmor, systemd ou à l'absence de conteneur peuvent être
`notapplicable`.

Pour un résultat de conformité exploitable, scannez une VM ou une machine
réelle correspondant exactement à la version du datastream :

| Datastream | Système attendu |
| --- | --- |
| `ssg-ubuntu2604-ds.xml` | Ubuntu 26.04 |

Un datastream Ubuntu 26.04 doit être évalué sur Ubuntu 26.04. Un datastream
Ubuntu 24.04 doit être évalué sur Ubuntu 24.04.

## Tester le projet

Validation rapide après une modification :

```bash
bash -n port-anssi.sh
docker build --check .
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=master \
  -t anssi-port:test .
```

Test du diagnostic :

```bash
docker run --rm anssi-port:test diagnose
```

Test du build complet :

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

Le build complet peut prendre plusieurs minutes. Le dossier `output-test/`
est jetable et évite d'écraser les résultats de travail.

## Erreurs fréquentes

### Produit introuvable

Message : `Le produit ... n'existe pas dans products/`.

Causes possibles : le nom n'existe pas dans la référence upstream choisie, ou
le produit n'est pas encore présent dans cette branche. Vérifiez :

```bash
docker run --rm anssi-port list
```

### Aucun profil ANSSI trouvé

Le produit source ne contient pas de fichier correspondant à
`anssi_bp28_*.profile`. Vérifiez `SOURCE_PRODUCT`, `TARGET_REF` et le contenu
du checkout upstream.

### `notapplicable` dans le rapport

Ce statut peut être normal. Vérifiez dans cet ordre :

1. le système scanné correspond-il à la version du datastream ?;
2. le scan est-il lancé dans un conteneur ?;
3. le paquet ou le service attendu est-il installé ?;
4. la règle exige-t-elle un noyau, GRUB, `/boot` ou systemd ?;
5. la règle a-t-elle été portée depuis Debian sans adaptation Ubuntu ?

### `rule not found`, `no applicable check` ou build interrompu

Consultez :

```text
output/logs/build-<produit>.log
```

Puis lancez `diagnose`. Une règle absente doit être retirée du profil ou
implémentée; une règle présente doit encore être vérifiée pour ses
plateformes, son OVAL et sa remédiation.

### Le build utilise des données inattendues

L'image clone `TARGET_REF` pendant sa construction. Rebuilder l'image après
un changement de référence :

```bash
docker build --no-cache \
  --build-arg TARGET_REF=<tag-ou-commit> \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  -t anssi-port:rebuild .
```

## Porter vers un autre OS

Le paramètre `TARGET_PRODUCT` permet de sélectionner un autre produit présent
dans `ComplianceAsCode/content`, mais il ne transforme pas automatiquement
les règles. Pour une autre distribution ou famille d'OS :

1. choisissez un produit source dont les profils et les règles sont proches;
2. confirmez que les règles existent avec `diagnose`;
3. inspectez les plateformes et checks OVAL;
4. vérifiez les noms de paquets, services et chemins;
5. testez les remédiations dans une VM dédiée;
6. comparez les résultats avec les exigences de l'OS cible.

Ajouter `multi_platform_ubuntu` à une règle ne suffit pas si son test ou sa
remédiation repose sur Debian, RPM, `authselect`, un chemin différent ou un
service absent.

## Documentation détaillée

- [Architecture et cycle de vie](docs/architecture.md)
- [Construire et diagnostiquer](docs/build.md)
- [Lancer OpenSCAP](docs/scap.md)
- [Tester le projet](docs/testing.md)
- [Dépannage et portage vers un autre OS](docs/troubleshooting.md)

## Références

- [ComplianceAsCode/content](https://github.com/ComplianceAsCode/content)
- [Documentation ComplianceAsCode](https://complianceascode.readthedocs.io/en/latest/)
- [OpenSCAP](https://www.open-scap.org/)
- [Guide ANSSI Linux](https://www.ssi.gouv.fr/administration/guide/recommandations-de-securite-relatives-a-un-systeme-gnulinux/)
