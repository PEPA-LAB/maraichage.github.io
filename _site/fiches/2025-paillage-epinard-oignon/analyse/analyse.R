# =============================================================================
# Paillages en maraîchage bio sur petite surface — Lauzelle, année 1 (2024–2025)
# -----------------------------------------------------------------------------
# Version consolidée et nettoyée des 9 scripts d'Eliot Vas (VESS.R, USDA.R,
# Lombric.R, infiltration.R, Adventices.R, Surf_Foliaire.R, Biomasse.R,
# c_micro_ms_mpn.R, Fertilisation.R). Seuls les MODÈLES RETENUS dans le mémoire
# (chapitre 5) sont repris. Les comparaisons de modèles exploratoires, les
# figures et les tests de diagnostic intermédiaires ne le sont pas.
#
# Travail d'origine : Eliot Vas, mémoire de fin d'études (UCLouvain, 2024–2025),
#   promoteur G. Lobet.
# Adaptation : PEPA Lab, 2026-11-17 (lecture de ../donnees.csv au lieu de
#   D:/.../Data.tot.xlsx ; facteurs reconstruits depuis l'identifiant de parcelle).
#
# Entrée  : ../donnees.csv (format long ; une ligne = une observation)
# Sorties : resultats_modeles.csv, moyennes_modalites.csv, figure_principale.png
# Packages (versions testées) : R 4.3.3 · readr 2.1.5 · dplyr 1.1.4 · tidyr 1.3.1 ·
#   lme4 1.1.35 · lmerTest 3.1.3 · performance 0.10.8 · emmeans 1.10.0 ·
#   car 3.1.2 · ggplot2 3.4.4
# Exécution : depuis analyse/ →  Rscript analyse.R
#
# Correspondance des noms : Vas « Row » (A–C) = colonne ; Vas « Col » (1–10) = rang ;
# Trait = modalite ; Bloc_Leg = bloc. On garde les noms de Vas dans les formules
# pour pouvoir comparer avec le mémoire.
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(ggplot2)
  library(lme4); library(lmerTest); library(performance); library(emmeans); library(car)
})

# ---- 1. Import ---------------------------------------------------------------
d <- read_csv("../donnees.csv", show_col_types = FALSE) |>
  mutate(Trait    = factor(modalite, levels = c("Bâche plastique", "BRF", "Miscanthus", "Trèfle", "Mix")),
         Row      = factor(colonne),
         Col      = factor(rang),
         Bloc_Leg = factor(bloc),
         Rep      = factor(repetition))

# ---- 2. Préparation ----------------------------------------------------------
# Sous-ensemble d'une variable (une ligne par répétition).
# Les doublons du fichier d'origine (flag « doublon ») sont moyennés, comme le
# faisaient les scripts d'origine (pivot_wider(values_fn = mean)).
# Les mesures marquées « hors protocole » (C1, couverture du 26/05) sont exclues.
sous <- function(v, ...) {
  d |> filter(variable == v, !is.na(valeur),
              !grepl("hors protocole", coalesce(flag, ""), fixed = TRUE), ...) |>
    group_by(parcelle, Trait, Row, Col, Bloc_Leg, Rep, date) |>
    summarise(Value = mean(valeur), .groups = "drop")
}
# Moyenne par parcelle (équivalent des variables *_moy du fichier d'origine)
par_parcelle <- function(df) {
  df |> group_by(parcelle, Trait, Row, Col, Bloc_Leg, date) |>
    summarise(Value = mean(Value), .groups = "drop")
}

# Résumé standard d'un modèle : p de Trait (et des autres termes fixes), R²
resume <- function(nom, m, type = 2) {
  a <- if (inherits(m, "merMod")) anova(m, type = type) else car::Anova(m, type = type)
  a <- as.data.frame(a); a$terme <- rownames(a)
  pcol <- grep("^Pr", names(a), value = TRUE)
  r2 <- if (inherits(m, "merMod")) {
    r <- performance::r2_nakagawa(m); c(r$R2_marginal, r$R2_conditional)
  } else c(summary(m)$r.squared, NA)
  tibble(variable = nom, terme = a$terme, p = a[[pcol]],
         r2_marginal = r2[1], r2_conditionnel = r2[2]) |>
    filter(terme != "Residuals")
}

# ---- 3. Descriptif -----------------------------------------------------------
vars_desc <- c("vess", "stabilite_agregats_usda", "lombrics_total", "infiltration_chabert",
               "adventices_cases_total", "adventices_especes", "couverture_foliaire",
               "biomasse_echantillon", "biomasse_plant", "carbone_microbien",
               "matiere_seche", "mpn_mycorhizes", "carbone_organique", "ph_kcl")
moyennes <- d |>
  filter(variable %in% vars_desc) |>
  group_by(variable, date, culture, Trait) |>
  summarise(n = sum(!is.na(valeur)), moyenne = mean(valeur, na.rm = TRUE),
            ecart_type = sd(valeur, na.rm = TRUE), .groups = "drop")
print(moyennes, n = 200)

# ---- 4. Modèles retenus dans le mémoire ---------------------------------------
res <- list()

# 4.1 Stabilité des agrégats USDA (p. 49–50) : interaction Trait × Bloc_Leg, Col aléatoire,
#     sur les 3 agrégats par parcelle. Row a été retiré après un LRT.
# ATTENTION : dans Data.tot.xlsx, 28 lignes USDA portaient un Bloc_Leg erroné
#     (corrigé ici d'après l'identifiant). L'interaction significative rapportée
#     (p = 0,0048) peut en dépendre : comparer avec le résultat ci-dessous.
usda <- sous("stabilite_agregats_usda")
res$usda <- resume("stabilite_agregats_usda", lmer(Value ~ Trait * Bloc_Leg + (1 | Col), data = usda))

# 4.2 VESS (p. 50–51) : modèle mixte sans interaction, Row et Col aléatoires, sur la
#     moyenne des 2 blocs par parcelle (REML = FALSE comme dans VESS.R)
vess <- par_parcelle(sous("vess"))
m_vess <- lmer(Value ~ Trait + (1 | Row) + (1 | Col), data = vess, REML = FALSE)
res$vess <- resume("vess", m_vess)
# Effet de la position (ANOVA à un facteur sur Row, p. 51)
print(summary(aov(Value ~ Row, data = vess)))

# 4.3 Vers de terre (p. 52) : aucun modèle mixte ne respectait les hypothèses,
#     d'où un modèle additif sur la racine carrée, par bloc de bêche
lomb <- sous("lombrics_total")
res$lomb <- resume("lombrics_total", lm(sqrt(Value) ~ Trait + Bloc_Leg, data = lomb))

# 4.4 Infiltration « Ariane Chabert » (p. 53) : sqrt, Col aléatoire
# ATTENTION : 12 cm/5 min est un plafond de la méthode (8 valeurs sur 30) :
#     les écarts en faveur de la bâche sont sous-estimés (p. 69).
inf <- sous("infiltration_chabert")
m_inf <- lmer(sqrt(Value) ~ Trait + (1 | Col), data = inf)
res$inf <- resume("infiltration_chabert", m_inf, type = 3)
print(pairs(emmeans(m_inf, ~ Trait), adjust = "tukey"))

# 4.5 Adventices : surface couverte (p. 56), log(x + 1), interaction, sans effet aléatoire
adv <- sous("adventices_cases_total")
res$adv <- resume("adventices_cases_total", lm(log(Value + 1) ~ Trait * Bloc_Leg, data = adv))
#     richesse spécifique (p. 57) : interaction + Col aléatoire
ric <- sous("adventices_especes")
res$ric <- resume("adventices_especes", lmer(Value ~ Trait * Bloc_Leg + (1 | Col), data = ric))

# 4.6 Couverture foliaire (p. 59–61), analysée par bloc et par date, sur la moyenne
#     des photos par parcelle
cf <- par_parcelle(sous("couverture_foliaire"))
res$cf11 <- resume("couverture_foliaire épinard 29/04",
                   lmer(Value ~ Trait + (1 | Col), data = filter(cf, Bloc_Leg == "1")))
res$cf21 <- resume("couverture_foliaire oignon 29/04",
                   lmer(Value ~ Trait + (1 | Row), data = filter(cf, Bloc_Leg == "2", date == as.Date("2025-04-29"))))
res$cf22 <- resume("couverture_foliaire oignon 26/05",
                   lmer(Value ~ Trait + (1 | Row), data = filter(cf, Bloc_Leg == "2", date == as.Date("2025-05-26"))))

# 4.7 Biomasse d'épinard (p. 62) : sqrt, Col aléatoire, sur les 3 échantillons de
#     9 plants par parcelle
bio <- sous("biomasse_echantillon")
m_bio <- lmer(sqrt(Value) ~ Trait + (1 | Col), data = bio)
res$bio <- resume("biomasse_echantillon", m_bio)
print(pairs(emmeans(m_bio, ~ Trait), adjust = "tukey"))
# Moyennes ajustées ramenées à l'échelle d'origine (carré de la moyenne sur sqrt,
# comme Biomasse.R ; sans correction de biais)
emm_bio <- as.data.frame(emmeans(m_bio, ~ Trait)) |> mutate(moy_ajustee_g = emmean^2)
print(emm_bio)

# 4.8 C microbien, matière sèche, MPN (p. 54–55) : une parcelle par modalité,
#     donc descriptif uniquement (voir moyennes_modalites.csv)

resultats <- bind_rows(res) |> mutate(across(where(is.numeric), ~ signif(.x, 3)))
print(resultats, n = 100)

# ---- 5. Figures --------------------------------------------------------------
# Biomasse d'épinard par plant (échantillon / 9), points = échantillons
fig <- d |> filter(variable == "biomasse_plant") |>
  mutate(Trait = factor(modalite, levels = levels(d$Trait))) |>
  ggplot(aes(Trait, valeur)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(width = 0.12, height = 0, size = 1.8) +
  labs(x = NULL, y = "Biomasse fraîche (g / plant)",
       title = "Épinard, récolte du 16 mai 2025 (Trèfle et Mix = sol nu)") +
  theme_minimal(base_size = 12)
ggsave("figure_principale.png", fig, width = 7, height = 4.5, dpi = 150)

# ---- 6. Export ---------------------------------------------------------------
write_csv(resultats, "resultats_modeles.csv")
write_csv(mutate(moyennes, across(c(moyenne, ecart_type), ~ round(.x, 3))), "moyennes_modalites.csv")
cat("Terminé : resultats_modeles.csv, moyennes_modalites.csv, figure_principale.png\n")
