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

## Vocabulaire contrôlé (pour que les filtres restent propres)

**Thèmes** : Paillage · Gestion de l'eau · Fertilisation · Couverts végétaux · Travail du sol ·
Variétés · Protection des cultures · Associations de cultures · Qualité nutritionnelle · Économie

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
