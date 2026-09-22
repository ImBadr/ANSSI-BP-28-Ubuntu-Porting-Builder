# Scanner avec OpenSCAP

## Deux conteneurs différents

Le conteneur builder et le conteneur scanner ont des rôles différents :

- `anssi-port build` génère le datastream puis s'arrête;
- un second conteneur Ubuntu peut fournir l'OS cible et exécuter OpenSCAP;
- une VM ou une vraie machine est nécessaire pour un scan complet du système.

La fin du conteneur builder est donc normale. Le résultat est conservé par le
volume `./output:/build/content/build`. Le scanner monte ensuite le même
dossier hôte sous `/profiles`.

## Préparer la machine cible

Le scanner doit être installé sur la machine Ubuntu à contrôler :

```bash
sudo apt update
sudo apt install -y openscap-scanner
oscap -V
```

Copiez le datastream généré sur cette machine, ou rendez le dossier `output/`
accessible. Le datastream doit correspondre exactement à la version majeure de
l'OS.

Sur macOS, `oscap` n'est généralement pas installé. Pour un test technique
dans un second conteneur Ubuntu 26.04 :

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap -V'
```

## Inspecter le datastream

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap info /profiles/ssg-ubuntu2604-ds.xml'
```

Relevez l'identifiant exact du profil, par exemple :

```text
xccdf_org.ssgproject.content_profile_anssi_bp28_enhanced
```

## Scan sans remédiation

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

Pour un test rapide :

```bash
sudo oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_anssi_bp28_minimal \
  --results results-anssi-minimal.xml \
  --report report-anssi-minimal.html \
  output/ssg-ubuntu2604-ds.xml
```

## Lire les résultats

```bash
open report-anssi-enhanced.html
```

Sur Linux, utilisez `xdg-open` à la place de `open`.

- `pass`: règle satisfaite.
- `fail`: règle applicable mais non satisfaite.
- `notapplicable`: règle non applicable au système ou au contexte.
- `notselected`: règle non sélectionnée par le profil.
- `error`: problème d'évaluation à investiguer.

Le code de sortie non nul d'OpenSCAP peut simplement indiquer des règles en échec. Le rapport HTML et le XML sont la source de vérité pour le détail.

## Remédiation

N'utilisez pas `--remediate` au premier scan. Il modifie le système et certaines corrections peuvent interrompre un service ou modifier l'accès administrateur.

Après revue, testez d'abord une règle ou un profil dans le second conteneur :

```bash
docker run --rm \
  -v "$PWD/output:/profiles" \
  ubuntu:26.04 \
  bash -lc 'apt-get update && apt-get install -y --no-install-recommends openscap-scanner && oscap xccdf eval \
  --profile xccdf_org.ssgproject.content_profile_anssi_bp28_minimal \
  --remediate \
  --results /profiles/results-after-remediation.xml \
  --report /profiles/report-after-remediation.html \
  /profiles/ssg-ubuntu2604-ds.xml'
```

Cette commande modifie le second conteneur, pas l'hôte. Avec `--rm`, les
modifications système disparaissent à la fin; les rapports restent dans
`./output/`. Pour remédier une vraie machine, installez OpenSCAP dessus et
lancez la commande directement avec `sudo`.

## Conteneurs

Le second conteneur Ubuntu permet de tester le pipeline et les règles
compatibles avec un conteneur, mais il ne représente pas une machine complète.
Les règles exigeant un noyau, GRUB, `/boot`, AppArmor, systemd ou un système
non conteneurisé peuvent être `notapplicable`. Utilisez une VM ou une machine
réelle pour un résultat de conformité.
