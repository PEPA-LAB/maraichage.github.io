# =============================================================================
# Irrigation du chou par oyas : distance oya–chou, rendement et racines
# Ferme universitaire de Marbaix, tunnel, mars–juin 2025
# -----------------------------------------------------------------------------
# Version nettoyée et resserrée de script_choux.R (Gaëlle Hanssens, mémoire
# UCLouvain 2024–2025, promoteur G. Lobet). Adaptation PEPA Lab, 2026-11-17.
#
# Ce qui change par rapport au script d'origine :
#   - lecture des CSV nettoyés (../donnees.csv, ../croissance.csv) au lieu des
#     chemins C:/ et D:/ ; plus d'install.packages() ;
#   - seuls les TESTS des figures principales sont gardés (les ~40 graphiques
#     du mémoire ne sont pas refaits) ; ACP et sondes TMS-4 non reprises
#     (sondes calibrées non transmises) ;
#   - post-hoc de Dunn via rstatix::dunn_test (correction de Holm), équivalent
#     de FSA::dunnTest utilisé à l'origine.
# La démarche statistique est celle du mémoire (p. 28–29) :
#   Shapiro-Wilk (résidus) + Levene →
#     ANOVA + Tukey       si les deux hypothèses tiennent,
#     Welch + Games-Howell si seule la normalité tient,
#     Kruskal-Wallis + Dunn (Holm) sinon.
#
# Entrées : ../donnees.csv (un chou × une variable)
# Sorties : resultats_tests.csv, medianes_traitements.csv, rendement_traitement.csv,
#           figure_principale.png
# Packages (versions testées) : R 4.3.3 · readr 2.1.5 · dplyr 1.1.4 · tidyr 1.3.1 ·
#   car 3.1.2 · rstatix 0.7.2 · ggplot2 3.4.4
# Exécution : depuis analyse/ →  Rscript analyse.R
# =============================================================================

# ---- 0. Packages -------------------------------------------------------------
suppressPackageStartupMessages({
  library(readr); library(dplyr); library(tidyr); library(car); library(rstatix); library(ggplot2)
})

# ---- 1. Import ---------------------------------------------------------------
niveaux <- c("100%", "Oya35", "Oya56", "Oya79", "0%")
d <- read_csv("../donnees.csv", show_col_types = FALSE) |>
  mutate(traitement = factor(traitement, levels = niveaux))

# Table large : une ligne par chou (les mesures datées, comme la conductance,
# sont traitées à part)
w <- d |>
  filter(variable != "conductance_stomatique") |>
  select(traitement, bloc, chou_id, variable, valeur) |>
  pivot_wider(names_from = variable, values_from = valeur)

# ---- 2. Choix du test (démarche du mémoire) -----------------------------------
teste <- function(df, y, nom = y) {
  df <- df |> filter(!is.na(.data[[y]])) |> droplevels()
  f <- as.formula(paste(y, "~ traitement"))
  m <- aov(f, data = df)
  p_sw <- shapiro.test(residuals(m))$p.value
  p_lev <- leveneTest(f, data = df)[1, "Pr(>F)"]
  if (p_sw > 0.05 && p_lev > 0.05) {
    s <- summary(m)[[1]]; tk <- tukey_hsd(df, f)
    test <- "ANOVA + Tukey"; stat <- s[1, "F value"]; p <- s[1, "Pr(>F)"]; ph <- tk
  } else if (p_sw > 0.05) {
    wa <- welch_anova_test(df, f); gh <- games_howell_test(df, f)
    test <- "Welch + Games-Howell"; stat <- wa$statistic; p <- wa$p; ph <- gh
  } else {
    kw <- kruskal_test(df, f); dn <- dunn_test(df, f, p.adjust.method = "holm")
    test <- "Kruskal-Wallis + Dunn (Holm)"; stat <- kw$statistic; p <- kw$p; ph <- dn
  }
  sig <- ph |> filter(p.adj < 0.05) |> mutate(paire = paste(group1, group2, sep = "-")) |> pull(paire)
  tibble(variable = nom, n = nrow(df), test = test, stat = unname(stat), p = p,
         paires_significatives = paste(sig, collapse = " ; "), p_shapiro = p_sw, p_levene = p_lev)
}

# ---- 3. Descriptif (médianes, comme les figures du mémoire) -------------------
vars <- c("biomasse_foliaire", "poids_chou", "diametre_chou", "hauteur_chou", "hauteur_plante",
          "eau_consommee", "wue_chou", "wue_biomasse", "longueur_racinaire_totale",
          "longueur_racinaire_in", "longueur_racinaire_out", "longueur_racinaire_diff_in_out")
medianes <- w |> pivot_longer(any_of(vars), names_to = "variable", values_to = "valeur") |>
  group_by(variable, traitement) |>
  summarise(n = sum(!is.na(valeur)), mediane = median(valeur, na.rm = TRUE),
            moyenne = mean(valeur, na.rm = TRUE), .groups = "drop")
print(medianes, n = 100)

# ---- 4. Tests ----------------------------------------------------------------
res <- bind_rows(
  teste(w, "hauteur_plante"),            # fig. 25B (27/05)
  teste(w, "diametre_chou"),             # fig. 25C
  teste(w, "hauteur_chou"),              # fig. 25D
  teste(w, "biomasse_foliaire"),         # fig. 27A
  teste(w, "poids_chou"),                # fig. 28A
  teste(w, "eau_consommee"),             # fig. 22B
  teste(w, "longueur_racinaire_totale")  # fig. 32A
)
# WUE : le mémoire compare les traitements IRRIGUÉS ; le 0 % (0,35 L) donne des
# valeurs sans signification physique et est exclu ici.
# ATTENTION : dans le script d'origine, le 0 % est inclus dans le test des WUE
# (fig. 30), ce qui crée à lui seul l'essentiel de la différence (F = 71,6).
wi <- filter(w, traitement != "0%")
res <- bind_rows(res,
  teste(wi, "wue_chou", "wue_chou (sans 0 %)"),
  teste(wi, "wue_biomasse", "wue_biomasse (sans 0 %)"))
# Distance à l'oya seule (3 traitements oyas), comme le mémoire le fait en complément
wo <- filter(w, grepl("Oya", traitement))
res <- bind_rows(res,
  teste(wo, "biomasse_foliaire", "biomasse_foliaire (oyas)"),
  teste(wo, "eau_consommee", "eau_consommee (oyas)"),
  teste(wo, "longueur_racinaire_diff_in_out", "diff racines in-out (oyas)"))
# ATTENTION : les 4 choux d'un bloc partagent la même oya (même eau_consommee) :
# l'unité expérimentale réelle est le bloc (n = 3 par traitement), pas le chou.
# Les tests ci-dessous, comme ceux du mémoire, traitent les choux comme indépendants.
res <- mutate(res, across(c(stat, p, p_shapiro, p_levene), ~ signif(.x, 3)))
print(res, width = Inf)

# Rendement à l'échelle du traitement (tableau 2 du mémoire, recalculé)
# surface = 0,25 m² par chou ; WUE en kg de chou par litre d'eau (unité cohérente)
rend <- w |> group_by(traitement) |>
  summarise(n_choux = n(),
            biomasse_t_ha = sum(biomasse_foliaire) / (n() * 0.25) * 10,
            choux_t_ha = sum(poids_chou) / (n() * 0.25) * 10,
            n_commercialisables = sum(commercialisable),
            commercialisables_t_ha = sum(poids_chou[commercialisable == 1]) / (n() * 0.25) * 10,
            eau_totale_l = sum(eau_consommee),
            wue_chou_kg_l = sum(poids_chou) / sum(eau_consommee), .groups = "drop") |>
  mutate(economie_eau_pct = 100 * (1 - (eau_totale_l / n_choux) / (eau_totale_l[traitement == "100%"] / n_choux[traitement == "100%"])))
print(rend, width = Inf)

# ---- 5. Figure ---------------------------------------------------------------
fig <- w |> ggplot(aes(traitement, poids_chou)) +
  geom_boxplot(outlier.shape = NA, fill = "grey90") +
  geom_jitter(aes(shape = factor(commercialisable)), width = 0.12, height = 0, size = 2) +
  scale_shape_manual(values = c(`0` = 4, `1` = 16), labels = c("non", "oui"), name = "Commercialisable") +
  labs(x = NULL, y = "Poids du chou paré (kg)", title = "Chou pointu, récolte du 5 juin 2025") +
  theme_minimal(base_size = 12)
ggsave("figure_principale.png", fig, width = 7, height = 4.5, dpi = 150)

# ---- 6. Export ---------------------------------------------------------------
write_csv(res, "resultats_tests.csv")
write_csv(mutate(medianes, across(c(mediane, moyenne), ~ round(.x, 4))), "medianes_traitements.csv")
write_csv(mutate(rend, across(where(is.numeric), ~ round(.x, 3))), "rendement_traitement.csv")
cat("Terminé.\n")
