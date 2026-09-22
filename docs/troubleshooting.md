# Dépannage et portage

## Distinguer les problèmes

### Erreur de build

Lire `output/logs/build-<produit>.log`. Une erreur de clone, de dépendance ou de rendu empêche la génération du datastream.

### Règle absente

`diagnose` recherche les `rule.yml` des sélections des profils source. Une règle absente doit être retirée, remplacée ou implémentée avant de considérer le profil comme fiable.

### Résultat `notapplicable`

Vérifier :

1. le CPE du datastream et la version de l'OS scanné;
2. le scan en conteneur ou sur une vraie machine;
3. la présence du paquet requis;
4. la présence du fichier ou du service requis;
5. les conditions de plateforme de la règle.

Un datastream Ubuntu 26.04 évalué sur Ubuntu 26.04 n'est pas un test valide, même si OpenSCAP produit un rapport.

### Résultat `error`

Un `error` est différent de `notapplicable`. Il peut signaler un OVAL non supporté, un fichier XML invalide, un problème de permissions ou une commande de check qui échoue de manière inattendue. Consultez le rapport et relancez la règle dans un environnement de test contrôlé.

## Portage vers un autre produit

`TARGET_PRODUCT` sélectionne un produit existant, mais ne traduit pas les contrôles. Pour chaque règle sélectionnée, vérifier :

- plateforme déclarée;
- OVAL et objets testés;
- chemins de fichiers;
- noms de paquets;
- noms de services;
- gestion de PAM;
- gestionnaire de paquets;
- remédiations Bash, Ansible et autres formats.

Une règle Debian peut être applicable à Ubuntu sans être correcte pour RHEL, Fedora, AlmaLinux ou un autre système. Ajouter une plateforme ne corrige pas un check ou une remédiation incompatible.

## Reproductibilité

Éviter `TARGET_REF=master` pour une validation formelle. Utiliser un tag ou un commit :

```bash
docker build \
  --build-arg SOURCE_PRODUCT=debian13 \
  --build-arg TARGET_PRODUCT=ubuntu2604 \
  --build-arg TARGET_REF=<commit-ou-tag> \
  -t anssi-port:<commit-ou-tag> .
```

Conserver le datastream, le rapport, le XML de résultats, la version OpenSCAP et l'identifiant de la machine évaluée.

## Limites du projet

Ce projet ne remplace pas une validation de conformité. Il automatise le rendu d'un profil porté et fournit un premier diagnostic. La sélection finale des règles, l'analyse des faux positifs et la validation des remédiations restent nécessaires.
