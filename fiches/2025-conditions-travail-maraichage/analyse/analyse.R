# =============================================================================
# Conditions de travail en maraîchage — Cœur de Condroz (2024–2025)
# -----------------------------------------------------------------------------
# SCRIPT DE LA FICHE, PAS L'ANALYSE ORIGINALE.
# Le mémoire repose sur une analyse qualitative (entretiens compréhensifs codés
# dans QualCoder) : il n'y a ni test statistique ni script d'origine. Ce script
# se limite à décrire les effectifs publiés (nombre de fermes citant chaque
# défi) et à produire la figure de la fiche.
#
# Travail d'origine : Augustin Peeters, mémoire de fin d'études (UCLouvain,
#   2024–2025), promoteur G. Lobet, co-promoteur N. Biot.
# Adaptation : PEPA Lab, 2026-11-20.
#
# Entrée  : ../donnees.csv (défis et étapes critiques, transcrits du mémoire)
# Sorties : figure_principale.png, etapes_critiques.csv
# Packages (versions testées) : R 4.3.3 · readr 2.1.5 · dplyr 1.1.4 · ggplot2 3.4.4
# Exécution : depuis analyse/ →  Rscript analyse.R
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
suppressPackageStartupMessages({ library(readr); library(dplyr); library(ggplot2) })

# ---- 1. Import ---------------------------------------------------------------
d <- read_csv("../donnees.csv", show_col_types = FALSE)

# ---- 2. Préparation ----------------------------------------------------------
defis <- d |> filter(type == "defi") |>
  mutate(dimension = factor(dimension, levels = c("Temps de travail", "Pénibilité physique", "Pénibilité psychologique")),
         variable = reorder(variable, n_fermes))

# ---- 3. Descriptif -----------------------------------------------------------
# Les effectifs sont des comptes de fermes (14 entretiens) : on ne calcule pas
# de pourcentages fins ni de tests, l'échantillon n'étant pas représentatif
# (démarche qualitative, mémoire p. 26).
print(defis |> select(dimension, variable, n_fermes) |> arrange(dimension, desc(n_fermes)), n = 20)

# Étapes critiques : effectif maximal par étape (une même ferme pouvant être
# comptée pour plusieurs variables, on ne somme PAS les effectifs)
etapes <- d |> filter(type == "etape_critique") |>
  group_by(etape) |>
  summarise(n_max = max(n_fermes), dimensions = paste(sort(unique(dimension)), collapse = " ; "), .groups = "drop") |>
  arrange(desc(n_max))
print(etapes, n = 20)

# ---- 4. Modèles / tests ------------------------------------------------------
# Aucun : étude qualitative.

# ---- 5. Figure ---------------------------------------------------------------
fig <- ggplot(defis, aes(n_fermes, variable, fill = dimension)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = n_fermes), hjust = -0.3, size = 3.6) +
  facet_grid(dimension ~ ., scales = "free_y", space = "free_y") +
  scale_x_continuous(limits = c(0, 14), breaks = c(0, 2, 4, 6, 8, 10, 12, 14), expand = c(0, 0)) +
  scale_fill_manual(values = c("#6baed6", "#e7969c", "#8cc5bd"), guide = "none") +
  labs(x = "Nombre de fermes (sur 14) citant ce défi", y = NULL,
       title = "Défis des conditions de travail cités par les maraîcher·ères",
       subtitle = "Cœur de Condroz, entretiens d'octobre 2024 à février 2025") +
  theme_minimal(base_size = 12) +
  theme(strip.text.y = element_text(angle = 0, hjust = 0, face = "bold"), panel.grid.major.y = element_blank())
ggsave("figure_principale.png", fig, width = 10, height = 6.25, dpi = 160)   # ≈ 1600 × 1000 px

# ---- 6. Export ---------------------------------------------------------------
write_csv(etapes, "etapes_critiques.csv")
cat("Terminé : figure_principale.png, etapes_critiques.csv\n")
