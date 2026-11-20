# Maraîchage · PEPA Lab

Site de partage des résultats d'essais et de recherche en maraîchage du PEPA Lab (UCLouvain).
Construit avec [Quarto](https://quarto.org), publié automatiquement sur GitHub Pages.

## Organisation du dépôt

```
maraichage/
├── _quarto.yml              ← configuration du site (menu, thème, pied de page)
├── index.qmd                ← accueil : grille de fiches triables / filtrables
├── themes.qmd               ← vue tableau par thème et culture
├── donnees.qmd              ← politique de données et liens d'archives
├── a-propos.qmd
├── styles.scss              ← design (couleurs, polices, cartes)
├── _templates/
│   └── fiche-card.ejs       ← gabarit des cartes de l'accueil
├── _includes/
│   └── ressources.qmd       ← bloc « Ressources + citation » commun à toutes les fiches
├── fiches/
│   ├── _metadata.yml        ← valeurs communes à toutes les fiches
│   ├── _modele/             ← MODÈLE à copier (non publié)
│   │   └── index.qmd
│   └── 2025-paillage-tomate/   ← une fiche = un dossier
│       ├── index.qmd           ← texte + métadonnées + graphique interactif
│       ├── donnees.csv         ← données résumées (< 5 Mo)
│       ├── dictionnaire.csv    ← (recommandé) description des colonnes
│       └── photo-essai.jpg     ← (optionnel)
├── protocoles.qmd          ← accueil des protocoles (filtres)
├── protocoles/
│   ├── _metadata.yml        ← valeurs communes à tous les protocoles
│   ├── _modele/             ← MODÈLE de protocole à copier (non publié)
│   └── vess-test-beche/     ← un protocole = un dossier
│       ├── index.qmd           ← carte d'identité, matériel, étapes, lecture, sources
│       └── fiche-releve.csv    ← fiche de terrain à imprimer
├── data/                    ← données transversales (météo, sols…)
├── documents/               ← PDF courts non déposés sur DIAL
└── .github/workflows/publish.yml  ← publication automatique
```

## Ajouter une fiche (5 minutes)

1. Copier `fiches/_modele/` → `fiches/AAAA-sujet-culture/` (minuscules, tirets, sans accents).
2. Remplir l'en-tête YAML : `title`, `annee`, `type`, `culture`, `categories`, `keywords`, `resultat`, `ressources`.
3. Écrire les sections (≈ 1 page) et déposer `donnees.csv`.
4. Commit + push sur `main` (ou Pull Request si étudiant·e). Le site se met à jour en ~2 min.

Pas besoin d'installer quoi que ce soit pour éditer : tout peut se faire dans l'interface web de GitHub.
Pour prévisualiser en local : `quarto preview`.

## Ajouter un protocole

1. Copier `protocoles/_modele/` → `protocoles/sujet-court/` (sans année : un protocole évolue).
2. Remplir l'en-tête : `objectif`, `difficulte` (Facile | Moyen | Avancé), `duree`, `cout`, `periode`, `categories`,
   et la liste `listing.contents` des fiches d'essais qui l'utilisent.
3. Rédiger pour un·e maraîcher·ère : matériel avec coût, étapes numérotées courtes, fiche de relevé, lecture des résultats, erreurs fréquentes.
4. Dans chaque fiche d'essai concernée, ajouter le lien dans l'encadré « Protocoles utilisés ».

## Conservatoire de tomates

Section `tomates/` : catalogue filtrable (`tomates/index.qmd` + `tomates/tomates.js`) et page « À propos ».
Les données sont de simples fichiers, lus directement par la page :

- `tomates/varietes.csv` : une ligne par variété (colonnes `id, cultivar, maturite, calibre, type, forme, couleur, bouche,
  croissance, rendement, sensibilite, plein_champs, date_graines, multiplication_2025, multiplication_2026, origine,
  utilisation, remarque`). `plein_champs` et `multiplication_*` valent `oui` ou `non`. Les filtres du site se construisent
  automatiquement à partir des valeurs présentes : une faute de frappe crée donc une valeur de filtre en plus.
- `tomates/photos.csv` : une ligne par photo (`variete_id, fichier, legende, type_photo`) ; fichiers dans `tomates/photos/<id>/`.
- `tomates/varietes.xlsx` : copie pour téléchargement, à régénérer si le CSV change beaucoup.

**Ajouter ou modifier une variété** : éditer `tomates/varietes.csv` sur GitHub (bouton crayon) ou dans un tableur
(enregistrer en « CSV UTF-8 »). Pour une nouvelle variété, prendre l'`id` suivant le plus grand existant.
**Supprimer** : retirer la ligne (et ses photos). **Ajouter une photo** :
`python3 outils/tomates_ajouter_photo.py <id> <photo.jpg> tomate "légende"`.
**Nouvelle année de multiplication** : ajouter une colonne `multiplication_2027` et l'afficher dans `tomates/tomates.js`.
L'import initial depuis l'application Shiny a été fait avec `outils/tomates_export.py` (corrections d'orthographe listées
dans `tomates/corrections.csv`).

## Vocabulaire contrôlé (pour que les filtres restent propres)

**Thèmes** : Paillage · Gestion de l'eau · Fertilisation · Couverts végétaux · Travail du sol ·
Variétés · Santé du sol · Protection des cultures · Adventices · Associations de cultures · Suivi des cultures · Qualité nutritionnelle · Économie

**Cultures** : utiliser le nom commun au singulier (Tomate, Laitue, Carotte, Poireau, Courge, Chou…).

Ajouter un thème = modifier cette liste dans une Pull Request, pour éviter les doublons
(« Irrigation » vs « Gestion de l'eau »).

## Données : règles

- Petits fichiers dans Git, gros fichiers bruts sur **Zenodo** (DOI, versionné, citable).
- Mémoires complets sur **DIAL** ; lien dans `ressources.memoire`.
- Toujours un dictionnaire de colonnes avec unités.
- Licence par défaut : CC BY 4.0 (texte) et CC BY 4.0 (données), sauf mention contraire.

## Mise en ligne (une seule fois)

1. Créer le dépôt GitHub (organisation du labo) et pousser ce dossier.
2. Lancer une fois `quarto publish gh-pages` en local **ou** laisser l'Action tourner.
3. Settings → Pages → Source : branche `gh-pages`.
4. Adapter `site-url` et `repo-url` dans `_quarto.yml`.
