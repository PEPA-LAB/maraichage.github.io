# =============================================================================
# Paillages et santé du sol en maraîchage bio sur petite surface — Lauzelle 2026
# -----------------------------------------------------------------------------
# SCRIPT DE LA FICHE, PAS L'ANALYSE ORIGINALE.
# Les scripts R/Rmd du mémoire n'ont pas été transmis. Ce script reproduit la
# structure de modèle décrite dans le mémoire (p. 37–38) pour les variables
# principales de la fiche, afin de vérifier les ordres de grandeur.
#
# Travail d'origine : Pierre-André Peters-Dickie, mémoire de fin d'études
#   (UCLouvain, 2025–2026), promoteur G. Lobet. Plateforme conçue par Eliot Vas (2025).
# Adaptation : PEPA Lab, 2026-11-17.
#
# Entrée  : ../donnees.csv (format long, une ligne = une parcelle × une variable × une date)
# Sorties : resultats_anova.csv, moyennes_modalites.csv, figure_principale.png
#           (écrits dans ce dossier analyse/)
# Packages (versions testées) : R 4.3.3 · readr 2.1.5 · dplyr 1.1.4 · tidyr 1.3.1 ·
#           car 3.1.2 · emmeans 1.10.0 · ggplot2 3.4.4
# Exécution : depuis le dossier analyse/ →  Rscript analyse.R
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr)
  library(car); library(emmeans); library(ggplot2)
})

# ---- 1. Import ---------------------------------------------------------------
d <- read_csv("../donnees.csv", show_col_types = FALSE)

# Ordre des modalités : témoin d'abord, puis paillages morts, puis vivants
niveaux <- c("Bâche plastique", "BRF", "Miscanthus", "Trèfle", "Mix")
d <- d |>
  mutate(modalite = factor(modalite, levels = niveaux),
         colonne  = factor(colonne),
         bloc     = factor(bloc))

# ---- 2. Préparation ----------------------------------------------------------
# On ne garde que la saison 2026 et on écarte les observations que le mémoire
# a lui-même exclues (flag contenant « écartée » : parcelle B9 en infiltration).
# Les autres flags (adventices, laitue rouge) sont informatifs : ces variables
# ne sont pas modélisées ici.
d26 <- d |>
  filter(saison == 2026, !grepl("écartée", coalesce(flag, ""), fixed = TRUE))

# Variables mesurées une seule fois sur les 30 parcelles → modèle complet
vars_30 <- c("vess", "carbone_total", "azote_total", "lombrics_total",
             "lombrics_endoges", "carbone_microbien", "humidite_ponderale",
             "infiltration_stabilisee")

# ---- 3. Descriptif -----------------------------------------------------------
moyennes <- d26 |>
  filter(variable %in% c(vars_30, "biomasse_plant", "spad")) |>
  group_by(variable, culture, modalite) |>
  summarise(n = sum(!is.na(valeur)),
            moyenne = mean(valeur, na.rm = TRUE),
            ecart_type = sd(valeur, na.rm = TRUE), .groups = "drop")
print(moyennes, n = 100)

# ---- 4. Modèles --------------------------------------------------------------
# Structure du mémoire : blocs aléatoires complets, Colonne (A–C) = facteur de
# blocage répliqué sur les 2 blocs légumes. En 2026, les facteurs spatiaux sont
# traités en EFFETS FIXES (choix de l'auteur, p. 36) pour décrire le gradient
# de la plateforme plutôt que de le neutraliser.
#   modèle : valeur ~ modalite + bloc + colonne   (ANOVA de type II)
# Type II car le plan est équilibré sauf exclusions ponctuelles (B9) : l'ordre
# des facteurs ne doit pas influencer le test.
ajuste <- function(df, formule) {
  m <- lm(formule, data = df)
  a <- car::Anova(m, type = "II")
  # Êta² partiel = SC_facteur / (SC_facteur + SC_résiduelle), comme dans le mémoire
  ss_res <- a["Residuals", "Sum Sq"]
  tibble(terme = rownames(a), sc = a[["Sum Sq"]], ddl = a[["Df"]],
         F = a[["F value"]], p = a[["Pr(>F)"]]) |>
    filter(terme != "Residuals") |>
    mutate(eta2_partiel = sc / (sc + ss_res))
}

res_30 <- d26 |>
  filter(variable %in% vars_30) |>
  group_by(variable) |>
  group_modify(~ ajuste(.x, valeur ~ modalite + bloc + colonne)) |>
  ungroup()

# Cultures de printemps : seulement 3 modalités × 3 parcelles par culture
# (Trèfle et Mix non cultivés). Pas de facteur bloc : chaque culture occupe un
# seul bloc. ATTENTION : 4 ddl résiduels seulement → tests peu puissants et
# tailles d'effet instables (le mémoire le signale, p. 44 et 47).
res_cult <- d26 |>
  filter(variable %in% c("biomasse_plant", "spad"),
         culture %in% c("Épinard", "Laitue")) |>
  group_by(variable, culture) |>
  group_modify(~ ajuste(droplevels(.x), valeur ~ modalite + colonne)) |>
  ungroup()

resultats <- bind_rows(res_30, res_cult) |>
  mutate(across(c(sc, F, p, eta2_partiel), ~ signif(.x, 3)))
print(resultats, n = 100)

# Comparaisons par paires (Tukey) pour la variable clé de la fiche : VESS
m_vess <- lm(valeur ~ modalite + bloc + colonne, data = filter(d26, variable == "vess"))
print(pairs(emmeans(m_vess, ~ modalite), adjust = "tukey"))

# ---- 5. Figures --------------------------------------------------------------
# Figure principale : structure du sol (VESS) par modalité, une boîte par
# modalité et les 6 parcelles en points. Score bas = meilleure structure.
fig <- d26 |>
  filter(variable == "vess") |>
  ggplot(aes(modalite, valeur)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.12, height = 0, size = 2) +
  scale_y_reverse() +
  labs(x = NULL, y = "Score VESS (1 = structure idéale, 5 = très compacte)",
       title = "Structure du sol en sortie d'hiver 2026 (avril)") +
  theme_minimal(base_size = 12)
ggsave("figure_principale.png", fig, width = 7, height = 4.5, dpi = 150)

# ---- 6. Export ---------------------------------------------------------------
write_csv(resultats, "resultats_anova.csv")
write_csv(mutate(moyennes, across(c(moyenne, ecart_type), ~ round(.x, 3))),
          "moyennes_modalites.csv")
cat("Terminé : resultats_anova.csv, moyennes_modalites.csv, figure_principale.png\n")
