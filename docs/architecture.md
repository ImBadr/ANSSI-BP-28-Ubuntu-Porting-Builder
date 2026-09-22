# Architecture du projet

## Vue d'ensemble

Le projet utilise une image de build Debian 13 pour produire du contenu SCAP pour un autre produit ComplianceAsCode.

```text
Dockerfile
    |
    +-- clone ComplianceAsCode/content
    +-- installe les outils de build
    +-- injecte port-anssi.sh
    |
    +-- port-anssi.sh build
            |
            +-- copie les profils source
            +-- build_product TARGET_PRODUCT
            +-- écrit build/ssg-<produit>-ds.xml
```

Le volume Docker `/build/content/build` est monté vers `./output` sur la machine hôte. Les artefacts du build et les logs survivent donc à la suppression du conteneur.

## Rôle des fichiers

- `Dockerfile`: environnement reproductible et paramètres de build.
- `port-anssi.sh`: point d'entrée et commandes opérationnelles.
- `README.md`: parcours complet de démarrage.
- `docs/`: documentation détaillée par sujet.
- `output/`: artefacts générés; ce dossier ne constitue pas le code source upstream.

## Paramètres

`SOURCE_PRODUCT` désigne le produit qui contient les profils source. `TARGET_PRODUCT` désigne le produit construit. `TARGET_REF` fixe la branche, le tag ou le commit de `ComplianceAsCode/content`.

Le portage copie les profils, mais ne convertit pas automatiquement les règles. Les plateformes, checks OVAL, remédiations et noms de paquets doivent être vérifiés pour le produit cible.

## Cycle de vie recommandé

1. Choisir une référence upstream.
2. Construire une image avec les arguments source et cible.
3. Exécuter `diagnose`.
4. Construire le datastream dans un dossier de sortie dédié.
5. Inspecter le datastream avec `oscap info`.
6. Scanner une VM ou une machine correspondant à la version cible.
7. Examiner les résultats `fail`, `notapplicable` et `error`.
8. Tester les remédiations séparément avant toute utilisation de `--remediate`.
