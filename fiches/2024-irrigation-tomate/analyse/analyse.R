# =============================================================================
# Stratégies d'irrigation de la tomate sous tunnel — Marbaix, 2024
# -----------------------------------------------------------------------------
# SCRIPT DE LA FICHE, PAS L'ANALYSE ORIGINALE (les scripts R du mémoire n'ont
# pas été transmis). Il applique la démarche décrite dans le mémoire (p. 41) :
#   Shapiro-Wilk (normalité des résidus) + Levene (homogénéité des variances)
#   → ANOVA à un facteur + Tukey si les hypothèses tiennent,
#   → sinon Kruskal-Wallis + comparaisons par paires (Wilcoxon, Bonferroni).
#   Note : le mémoire cite le test de Dunn. On utilise ici pairwise.wilcox.test
#   (R de base) pour éviter une dépendance supplémentaire ; les conclusions
#   peuvent légèrement différer.
#
# Travail d'origine : Clémentine Lucca, mémoire de fin d'études (UCLouvain,
#   2024–2025), promoteur G. Lobet.
# Adaptation : PEPA Lab, 2026-11-17.
#
# Entrées : ../donnees.csv (un plant × une variable), ../fruits.csv (un fruit)
# Sorties : resultats_tests.csv, medianes_traitements.csv, figure_principale.png
# Packages (versions testées) : R 4.3.3 · readr 2.1.5 · dplyr 1.1.4 · car 3.1.2 · ggplot2 3.4.4
# Exécution : depuis analyse/ →  Rscript analyse.R
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(car); library(ggplot2)
})

# ---- 1. Import ---------------------------------------------------------------
niveaux <- c("100P", "50P", "0P", "oya", "direct")
d <- read_csv("../donnees.csv", show_col_types = FALSE) |>
  mutate(traitement = factor(traitement, levels = niveaux))
fr <- read_csv("../fruits.csv", show_col_types = FALSE) |>
  mutate(traitement = factor(traitement, levels = niveaux))

# ---- 2. Préparation ----------------------------------------------------------
# Unité statistique = le plant (9 plants par traitement, 3 par planche).
# ATTENTION : les 3 plants d'une même planche ne sont pas indépendants (même
# planche, même ligne de goutte-à-goutte ou même oya). Le mémoire les traite
# comme indépendants ; on fait de même pour reproduire ses résultats, mais
# un modèle mixte avec la planche en effet aléatoire serait plus prudent.
vars <- c("rendement_plant", "rendement_commercialisable", "fruits_nombre",
          "fruits_commercialisables", "inflorescences_total", "inflorescences_productives",
          "fleurs_total", "taux_avortement", "fleurs_par_inflorescence",
          "fruits_par_inflorescence", "eau_irrigation")

# ---- 3. Descriptif (le mémoire présente des médianes, p. 41) ------------------
medianes <- d |>
  filter(variable %in% c(vars, "rendement_par_litre")) |>
  group_by(variable, traitement) |>
  summarise(n = sum(!is.na(valeur)), mediane = median(valeur, na.rm = TRUE),
            moyenne = mean(valeur, na.rm = TRUE), total = sum(valeur, na.rm = TRUE),
            .groups = "drop")
print(medianes, n = 100)

# ---- 4. Tests ----------------------------------------------------------------
teste <- function(df, nom) {
  df <- filter(df, !is.na(valeur))
  m <- aov(valeur ~ traitement, data = df)
  p_shapiro <- shapiro.test(residuals(m))$p.value
  p_levene  <- leveneTest(valeur ~ traitement, data = df)[1, "Pr(>F)"]
  if (p_shapiro > 0.05 && p_levene > 0.05) {
    s <- summary(m)[[1]]
    tk <- TukeyHSD(m)$traitement
    sig <- rownames(tk)[tk[, "p adj"] < 0.05]
    tibble(variable = nom, test = "ANOVA + Tukey", stat = s[1, "F value"],
           ddl = paste(s[1, "Df"], s[2, "Df"], sep = ","), p = s[1, "Pr(>F)"],
           paires_significatives = paste(sig, collapse = " ; "),
           p_shapiro = p_shapiro, p_levene = p_levene)
  } else {
    kw <- kruskal.test(valeur ~ traitement, data = df)
    pw <- pairwise.wilcox.test(df$valeur, df$traitement, p.adjust.method = "bonferroni", exact = FALSE)$p.value
    idx <- which(pw < 0.05, arr.ind = TRUE)
    sig <- if (nrow(idx)) paste(rownames(pw)[idx[, 1]], colnames(pw)[idx[, 2]], sep = "-") else character(0)
    tibble(variable = nom, test = "Kruskal-Wallis + Wilcoxon (Bonferroni)", stat = unname(kw$statistic),
           ddl = as.character(kw$parameter), p = kw$p.value,
           paires_significatives = paste(sig, collapse = " ; "),
           p_shapiro = p_shapiro, p_levene = p_levene)
  }
}
res <- bind_rows(lapply(setdiff(vars, "eau_irrigation"), function(v) teste(filter(d, variable == v), v)))

# Poids individuel des fruits (unité = fruit, p. 57) : le mémoire utilise
# Kruskal-Wallis puis Wilcoxon par paires.
res <- bind_rows(res, teste(transmute(fr, traitement, valeur = poids_g), "poids_fruit (par fruit)"))
res <- mutate(res, across(c(stat, p, p_shapiro, p_levene), ~ signif(.x, 3)))
print(res, width = Inf)

# ---- 5. Figures --------------------------------------------------------------
fig <- d |> filter(variable == "rendement_plant") |>
  ggplot(aes(traitement, valeur / 1000)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.12, height = 0, size = 2) +
  labs(x = NULL, y = "Rendement (kg de fruits / plant)",
       title = "Tomate 'Tigerella' sous tunnel, récoltes du 7/08 au 2/10/2024") +
  theme_minimal(base_size = 12)
ggsave("figure_principale.png", fig, width = 7, height = 4.5, dpi = 150)

# ---- 6. Export ---------------------------------------------------------------
write_csv(res, "resultats_tests.csv")
write_csv(mutate(medianes, across(c(mediane, moyenne, total), ~ round(.x, 4))), "medianes_traitements.csv")
cat("Terminé : resultats_tests.csv, medianes_traitements.csv, figure_principale.png\n")
