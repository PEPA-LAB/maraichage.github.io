# =============================================================================
# Coûts de production des fermes maraîchères du Cœur de Condroz (2022)
# Objectif : décrire les postes de coûts opérationnels (Tableau 2) et produire
#            la figure de la fiche.
# Source   : Heine B., Gaspart F., Biot N. (2025). Developing indicators to assess
#            the viability of small- and medium-scale farms. Front. Sustain. Food
#            Syst. 9:1608860. https://doi.org/10.3389/fsufs.2025.1608860
# Script de la fiche (PEPA Lab, 2026-11-21), pas l'analyse originale : les données
#            individuelles n'étant pas publiées, il travaille sur les statistiques
#            descriptives recopiées des Tableaux 1 et 2. L'ACP et les modèles
#            linéaires de l'article ne peuvent pas être refaits.
# Entrées  : ../donnees.csv
# Sorties  : figure_principale.png, couts_resume.csv
# Packages : readr, dplyr, tidyr, ggplot2 (testé avec R 4.3)
# =============================================================================

# 0. Packages -----------------------------------------------------------------
library(readr); library(dplyr); library(tidyr); library(ggplot2)

# 1. Import -------------------------------------------------------------------
d <- read_csv("../donnees.csv", show_col_types = FALSE)

# 2. Préparation --------------------------------------------------------------
couts <- d |> filter(tableau == "couts") |>
  select(variable, statistique, valeur, flag) |>
  pivot_wider(names_from = statistique, values_from = valeur) |>
  arrange(desc(moyenne))

# 3. Descriptif ---------------------------------------------------------------
# Somme des coûts moyens : ordre de grandeur des coûts opérationnels par ferme.
# (La somme des moyennes est la moyenne des sommes, car les 17 fermes sont
# présentes pour chaque poste.)
total <- sum(couts$moyenne)
couts <- couts |> mutate(part_pct = round(100 * moyenne / total, 1))
cat("Coûts opérationnels moyens (8 postes) :", round(total), "€/ferme/an\n")
print(couts)

# Comparaison au chiffre d'affaires moyen (Tableau 1)
ca <- d |> filter(variable == "Chiffre d'affaires", statistique == "moyenne") |> pull(valeur)
cat("Soit", round(100 * total / ca, 1), "% du chiffre d'affaires moyen\n")

# ATTENTION : pour les pesticides, la moyenne publiée (1 277 €) dépasse le
# maximum (1 000 €), ce qui est impossible. La valeur est gardée et signalée.

# 4. Modèles ------------------------------------------------------------------
# Non reproductibles sans les données individuelles (voir ../modeles.csv pour
# les coefficients publiés).

# 5. Figure -------------------------------------------------------------------
couts <- couts |> mutate(variable = factor(variable, levels = rev(variable)))
fig <- ggplot(couts, aes(y = variable)) +
  geom_segment(aes(x = min, xend = max, yend = variable), linewidth = 2.2, colour = "#d9e6dd", lineend = "round") +
  geom_point(aes(x = mediane, shape = "Médiane", colour = "Médiane"), size = 3.6) +
  geom_point(aes(x = moyenne, shape = "Moyenne", colour = "Moyenne"), size = 4) +
  geom_text(aes(x = pmax(max, moyenne), label = paste0(format(round(moyenne), big.mark = " "), " €",
                                                       ifelse(is.na(flag), "", " *"))),
            hjust = -0.25, size = 4.2, colour = "grey30") +
  scale_shape_manual(values = c("Médiane" = 16, "Moyenne" = 18), name = NULL) +
  scale_colour_manual(values = c("Médiane" = "#2a7a4b", "Moyenne" = "#b5651d"), name = NULL) +
  scale_x_continuous(labels = function(x) format(x, big.mark = " "), limits = c(0, 19000),
                     expand = c(0, 0)) +
  labs(x = "Coût annuel par ferme (€, 2022) ; barre = minimum à maximum", y = NULL,
       title = "Les plants et le carburant sont les plus gros postes de coûts",
       subtitle = "17 fermes maraîchères du Cœur de Condroz ; étiquette = coût moyen",
       caption = "* Pesticides : moyenne publiée supérieure au maximum (incohérence du Tableau 2)") +
  theme_minimal(base_size = 15) +
  theme(panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
        legend.position = "top", legend.justification = "left",
        plot.title = element_text(face = "bold"))
ggsave("figure_principale.png", fig, width = 10, height = 6.25, dpi = 160, bg = "white")

# 6. Export -------------------------------------------------------------------
write_csv(couts, "couts_resume.csv")
