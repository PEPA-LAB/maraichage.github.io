# =============================================================================
# Canaux de vente des maraîchers du Cœur de Condroz
# Objectif : décrire la part du chiffre d'affaires (CA) réalisée par canal de
#            distribution, et comparer petites et moyennes fermes.
# Source   : Biot N., Hecquet C., Maréchal K., Lobet G., Dendoncker N. (2026).
#            Agroecology and Sustainable Food Systems 50(7) : 1766-1796.
#            https://doi.org/10.1080/21683565.2025.2597006 (données : annexe xlsx)
# Script de la fiche (PEPA Lab, 2026-11-21), pas le script original des auteurs :
#            il reproduit l'annexe F (moyennes et tests de Wilcoxon) et la figure 3.
# Entrées  : ../donnees.csv
# Sorties  : figure_principale.png, moyennes_par_orientation.csv
# Packages : readr, dplyr, tidyr, ggplot2, rstatix (testé avec R 4.3)
# =============================================================================

# 0. Packages -----------------------------------------------------------------
library(readr); library(dplyr); library(tidyr); library(ggplot2); library(rstatix)

# 1. Import -------------------------------------------------------------------
d <- read_csv("../donnees.csv", show_col_types = FALSE)

# 2. Préparation --------------------------------------------------------------
ordre_canaux <- c("Vente à la ferme", "Marchés", "Paniers", "Coopératives locales",
                  "Magasins locaux", "Horeca", "Institutions locales",
                  "Grossistes", "Supermarchés", "Autres")
d <- d |> mutate(canal = factor(canal, levels = ordre_canaux),
                 orientation = factor(orientation, levels = c("Petite surface", "Moyenne surface")))

# 3. Descriptif ---------------------------------------------------------------
# Chaque ferme vend 100 % de son CA : vérification
stopifnot(all(abs(tapply(d$part_ca, d$ferme, sum) - 100) < 0.01))

# Part locale moyenne (article : 97 %)
part_locale <- d |> group_by(ferme) |> summarise(local = sum(part_ca[canal_local == "oui"]))
cat("Part moyenne du CA vendue en local :", round(mean(part_locale$local), 1), "%\n")

# Nombre de canaux utilisés par ferme (part > 0)
n_canaux <- d |> filter(part_ca > 0) |> count(ferme, orientation, name = "n_canaux")
print(n_canaux |> group_by(orientation) |> summarise(moyenne = mean(n_canaux), min = min(n_canaux), max = max(n_canaux)))

# 4. Tests --------------------------------------------------------------------
# Comme dans l'article : test de Wilcoxon (rangs) par canal, car les parts ne
# suivent pas une loi normale, puis correction de Holm sur les 10 canaux.
# ATTENTION : 4 fermes seulement en moyenne surface, puissance très faible ;
# les p-values sont exploratoires (l'étude couvre toutes les fermes du territoire).
# ATTENTION : les p-values de l'annexe F, présentées comme ajustées (Holm),
# correspondent aux p brutes ci-dessous (colonne p). Après correction de Holm
# (colonne p.adj), aucune différence n'est significative au seuil de 5 %.
moy <- d |> group_by(canal, orientation) |> summarise(moyenne = mean(part_ca), .groups = "drop") |>
  pivot_wider(names_from = orientation, values_from = moyenne)
tests <- d |> group_by(canal) |> wilcox_test(part_ca ~ orientation, exact = FALSE) |>
  adjust_pvalue(method = "holm") |> select(canal, p, p.adj)
res <- left_join(moy, tests, by = "canal")
print(res, n = 20)

# 5. Figure -------------------------------------------------------------------
# Une barre par ferme, empilée par canal (équivalent de la figure 3 de l'article).
ordre_fermes <- d |> filter(canal == "Vente à la ferme") |> arrange(orientation, desc(part_ca)) |> pull(ferme)
couleurs <- c("Vente à la ferme" = "#2a7a4b", "Marchés" = "#7fbf7b", "Paniers" = "#c2e0a3",
              "Coopératives locales" = "#e6b450", "Magasins locaux" = "#f3d79a", "Horeca" = "#b07aa1",
              "Institutions locales" = "#d4b9d0", "Grossistes" = "#6b7c93", "Supermarchés" = "#3d4b5c",
              "Autres" = "#cfcfcf")
fig <- ggplot(d, aes(x = factor(ferme, levels = ordre_fermes), y = part_ca, fill = canal)) +
  geom_col(width = 0.85) +
  facet_grid(~ orientation, scales = "free_x", space = "free_x") +
  scale_fill_manual(values = couleurs, name = NULL) +
  scale_y_continuous(expand = c(0, 0), labels = function(x) paste0(x, " %")) +
  labs(x = "Ferme (identifiant anonyme)", y = "Part du chiffre d'affaires légumes (2021)",
       title = "Chaque ferme combine ses propres canaux de vente",
       subtitle = "18 maraîchers du Cœur de Condroz ; 97 % du chiffre d'affaires vendu localement") +
  theme_minimal(base_size = 15) +
  theme(panel.grid.major.x = element_blank(), legend.position = "bottom",
        axis.text.x = element_text(angle = 90, vjust = 0.5, size = 11),
        strip.text = element_text(face = "bold"), plot.title = element_text(face = "bold")) +
  guides(fill = guide_legend(nrow = 2))
ggsave("figure_principale.png", fig, width = 10, height = 6.25, dpi = 160, bg = "white")

# 6. Export -------------------------------------------------------------------
write_csv(res |> mutate(across(where(is.numeric), \(x) round(x, 3))), "moyennes_par_orientation.csv")
