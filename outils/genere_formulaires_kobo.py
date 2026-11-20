"""Génère un XLSForm (compatible KoboToolbox / ODK) par protocole du site Maraîchage PEPA Lab.

Usage : python genere_formulaires.py <dossier_sortie>
Chaque formulaire reprend les colonnes de la fiche-releve.csv du protocole.
"""
import sys
from pathlib import Path
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill

SURVEY_COLS = ["type", "name", "label", "hint", "required", "default",
               "constraint", "constraint_message", "relevant", "calculation", "appearance", "parameters"]

# Champs communs en tête de chaque formulaire
ENTETE = [
    {"type": "start", "name": "debut"},
    {"type": "end", "name": "fin"},
    {"type": "date", "name": "date", "label": "Date du relevé", "required": "yes", "default": "today()"},
    {"type": "text", "name": "parcelle", "label": "Parcelle ou planche", "hint": "Code utilisé sur votre plan, ex. P01", "required": "yes"},
    {"type": "text", "name": "operateur", "label": "Personne qui fait le relevé"},
]
FIN = [
    {"type": "geopoint", "name": "position", "label": "Position (facultatif)", "hint": "Utile pour retrouver le point l'année suivante"},
    {"type": "text", "name": "remarques", "label": "Remarques", "appearance": "multiline"},
]

FORMS = {}

FORMS["vess-test-beche"] = {
    "title": "VESS et test bêche – PEPA Lab",
    "survey": ENTETE + [
        {"type": "integer", "name": "bloc", "label": "Numéro du bloc dans la parcelle", "default": "1"},
        {"type": "image", "name": "photo_bloc", "label": "Photo du bloc sorti"},
        {"type": "begin_repeat", "name": "couche", "label": "Couches du bloc (une par couche visible)"},
        {"type": "integer", "name": "epaisseur_cm", "label": "Épaisseur de la couche (cm)", "required": "yes",
         "constraint": ". > 0 and . <= 40", "constraint_message": "Entre 1 et 40 cm"},
        {"type": "select_one note_vess", "name": "note_vess", "label": "Note VESS de la couche", "required": "yes",
         "hint": "1 friable · 2 intact · 3 ferme · 4 compact · 5 très compact"},
        {"type": "calculate", "name": "produit", "calculation": "${epaisseur_cm} * ${note_vess}"},
        {"type": "end_repeat", "name": "couche"},
        {"type": "calculate", "name": "epaisseur_totale", "calculation": "sum(${epaisseur_cm})"},
        {"type": "calculate", "name": "note_bloc", "calculation": "round(sum(${produit}) div sum(${epaisseur_cm}), 1)"},
        {"type": "note", "name": "affiche_note", "label": "Note du bloc : **${note_bloc}** sur ${epaisseur_totale} cm (1 = idéal, 5 = très compact)"},
        {"type": "begin_group", "name": "vers", "label": "Vers de terre (test bêche)"},
        {"type": "integer", "name": "nb_epiges", "label": "Épigés", "default": "0", "constraint": ". >= 0"},
        {"type": "integer", "name": "nb_endoges", "label": "Endogés", "default": "0", "constraint": ". >= 0"},
        {"type": "integer", "name": "nb_epi_aneciques", "label": "Épi-anéciques", "default": "0", "constraint": ". >= 0"},
        {"type": "integer", "name": "nb_aneciques_stricts", "label": "Anéciques stricts", "default": "0", "constraint": ". >= 0"},
        {"type": "calculate", "name": "nb_vers_total",
         "calculation": "${nb_epiges} + ${nb_endoges} + ${nb_epi_aneciques} + ${nb_aneciques_stricts}"},
        {"type": "note", "name": "affiche_vers", "label": "Total : **${nb_vers_total}** vers dans le bloc"},
        {"type": "end_group", "name": "vers"},
    ] + FIN,
    "choices": [("note_vess", str(v), str(v).replace(".", ","), None)
                for v in [1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5]],
}

FORMS["stabilite-agregats"] = {
    "title": "Stabilité des mottes dans l'eau – PEPA Lab",
    "survey": ENTETE + [
        {"type": "begin_repeat", "name": "agregat", "label": "Agrégats testés (3 à 9 par parcelle)"},
        {"type": "select_one moitie", "name": "moitie_dissoute", "label": "La moitié de l'agrégat s'est dissoute…", "required": "yes"},
        {"type": "integer", "name": "pct_restant", "label": "Part restante après 5 immersions (%)",
         "relevant": "${moitie_dissoute} = 'non'", "required": "yes",
         "constraint": ". >= 0 and . <= 100", "constraint_message": "Entre 0 et 100 %"},
        {"type": "calculate", "name": "score",
         "calculation": "if(${moitie_dissoute} = 'filtre', 0, if(${moitie_dissoute} = 'moins_5s', 1, "
                        "if(${moitie_dissoute} = '5_30s', 2, if(${moitie_dissoute} = '30s_5min', 3, "
                        "if(${pct_restant} < 10, 3, if(${pct_restant} < 25, 4, if(${pct_restant} < 75, 5, 6)))))))"},
        {"type": "note", "name": "affiche_score", "label": "Score de cet agrégat : **${score}** sur 6"},
        {"type": "end_repeat", "name": "agregat"},
        {"type": "calculate", "name": "score_moyen", "calculation": "round(sum(${score}) div count(${score}), 1)"},
        {"type": "note", "name": "affiche_moyen", "label": "Score moyen de la parcelle : **${score_moyen}** sur 6"},
    ] + FIN,
    "choices": [
        ("moitie", "filtre", "Tout est passé à travers le filtre (score 0)", None),
        ("moitie", "moins_5s", "En moins de 5 secondes (score 1)", None),
        ("moitie", "5_30s", "Entre 5 et 30 secondes (score 2)", None),
        ("moitie", "30s_5min", "Entre 30 secondes et 5 minutes (score 3)", None),
        ("moitie", "non", "Pas après 5 minutes : faire les 5 immersions", None),
    ],
}

FORMS["infiltration-tube"] = {
    "title": "Infiltration au tube – PEPA Lab",
    "survey": ENTETE + [
        {"type": "integer", "name": "point", "label": "Numéro du point", "default": "1"},
        {"type": "text", "name": "pratique", "label": "Pratique ou paillage", "hint": "ex. BRF, bâche, sol nu"},
        {"type": "select_one oui_non", "name": "absorbee_15min", "label": "Le premier 1,25 L a-t-il disparu en moins de 15 minutes ?", "required": "yes"},
        {"type": "decimal", "name": "hauteur_debut_cm", "label": "Hauteur d'eau au début de la mesure (cm)",
         "hint": "Juste après le 2e versement si oui ; à 15 minutes si non", "required": "yes"},
        {"type": "decimal", "name": "hauteur_fin_cm", "label": "Hauteur d'eau 5 minutes plus tard (cm)", "required": "yes",
         "constraint": ". <= ${hauteur_debut_cm}", "constraint_message": "Le niveau ne peut pas monter"},
        {"type": "calculate", "name": "baisse_cm_5min", "calculation": "${hauteur_debut_cm} - ${hauteur_fin_cm}"},
        {"type": "calculate", "name": "vitesse_mm_h", "calculation": "round(${baisse_cm_5min} * 120, 0)"},
        {"type": "note", "name": "affiche_vitesse", "label": "Baisse : ${baisse_cm_5min} cm en 5 min, soit **${vitesse_mm_h} mm/h**"},
    ] + FIN,
    "choices": [("oui_non", "oui", "Oui", None), ("oui_non", "non", "Non", None)],
}

FORMS["oyas-installation"] = {
    "title": "Suivi des oyas – PEPA Lab",
    "survey": ENTETE + [
        {"type": "text", "name": "oya", "label": "Identifiant de l'oya", "hint": "ex. O1", "required": "yes"},
        {"type": "select_one releve", "name": "type_releve", "label": "Type de relevé", "required": "yes"},
        {"type": "integer", "name": "distance_plant_cm", "label": "Distance oya – plants (cm)", "relevant": "${type_releve} = 'installation'"},
        {"type": "integer", "name": "nb_plants", "label": "Nombre de plants autour de l'oya", "default": "4", "relevant": "${type_releve} = 'installation'"},
        {"type": "decimal", "name": "volume_ajoute_L", "label": "Volume versé pour remplir l'oya (L)",
         "relevant": "${type_releve} != 'fin'", "required": "yes", "constraint": ". >= 0"},
        {"type": "decimal", "name": "volume_restant_fin_L", "label": "Eau restant dans l'oya après la récolte (L)",
         "relevant": "${type_releve} = 'fin'", "required": "yes", "constraint": ". >= 0"},
    ] + FIN,
    "choices": [
        ("releve", "installation", "Installation et premier remplissage", None),
        ("releve", "remplissage", "Remplissage en cours de saison", None),
        ("releve", "fin", "Fin de saison (eau restante)", None),
    ],
}

FORMS["prelevement-sol-analyse"] = {
    "title": "Prélèvement de sol pour analyse – PEPA Lab",
    "survey": ENTETE + [
        {"type": "integer", "name": "nb_prelevements", "label": "Nombre de prélèvements en zigzag", "default": "15", "constraint": ". >= 1"},
        {"type": "integer", "name": "profondeur_cm", "label": "Profondeur (cm)", "default": "25"},
        {"type": "integer", "name": "masse_envoyee_g", "label": "Masse de l'échantillon (g)", "default": "500"},
        {"type": "select_multiple analyse", "name": "analyse_demandee", "label": "Analyse demandée", "required": "yes"},
        {"type": "note", "name": "rappel_bio", "label": "Échantillon pour le carbone microbien : à garder **frais et humide**, au froid, sachet entrouvert.",
         "relevant": "selected(${analyse_demandee}, 'biologique')"},
        {"type": "text", "name": "laboratoire", "label": "Laboratoire"},
        {"type": "text", "name": "code_echantillon", "label": "Code inscrit sur l'étiquette"},
    ] + FIN,
    "choices": [("analyse", "chimique", "Chimique (pH, C, N, P, K, Mg, Ca…)", None),
                ("analyse", "biologique", "Biologique (carbone microbien)", None)],
}

FORMS["adventices-couverture"] = {
    "title": "Adventices et couverture – PEPA Lab",
    "survey": ENTETE + [
        {"type": "select_multiple methode", "name": "methode", "label": "Méthode(s) utilisée(s)", "required": "yes"},
        {"type": "begin_group", "name": "cadre", "label": "Cadre grillagé (196 cases de 5 × 5 cm)", "relevant": "selected(${methode}, 'cadre')"},
        {"type": "integer", "name": "cases_adventices", "label": "Cases couvertes à 50 % ou plus par des adventices", "required": "yes",
         "constraint": ". >= 0 and . <= 196", "constraint_message": "Entre 0 et 196"},
        {"type": "calculate", "name": "pct_adventices", "calculation": "round(${cases_adventices} div 196 * 100, 1)"},
        {"type": "note", "name": "affiche_pct", "label": "Surface couverte par les adventices : **${pct_adventices} %**"},
        {"type": "text", "name": "especes", "label": "Espèces identifiées et nombre de pieds", "appearance": "multiline",
         "hint": "ex. chénopode 4 ; mouron 12"},
        {"type": "image", "name": "photo_cadre", "label": "Photo du cadre"},
        {"type": "end_group", "name": "cadre"},
        {"type": "begin_group", "name": "canopeo", "label": "Photos Canopeo (une par tiers de planche)", "relevant": "selected(${methode}, 'canopeo')"},
        {"type": "select_one lumiere", "name": "conditions_lumiere", "label": "Conditions de lumière", "required": "yes"},
        {"type": "decimal", "name": "couverture_1", "label": "Couverture photo 1 (%)", "constraint": ". >= 0 and . <= 100"},
        {"type": "decimal", "name": "couverture_2", "label": "Couverture photo 2 (%)", "constraint": ". >= 0 and . <= 100"},
        {"type": "decimal", "name": "couverture_3", "label": "Couverture photo 3 (%)", "constraint": ". >= 0 and . <= 100"},
        {"type": "calculate", "name": "couverture_moyenne", "calculation": "round((${couverture_1} + ${couverture_2} + ${couverture_3}) div 3, 1)"},
        {"type": "note", "name": "affiche_couv", "label": "Couverture moyenne : **${couverture_moyenne} %**"},
        {"type": "end_group", "name": "canopeo"},
    ] + FIN,
    "choices": [("methode", "cadre", "Cadre grillagé (adventices)", None),
                ("methode", "canopeo", "Photos Canopeo (couverture totale)", None),
                ("lumiere", "nuageux", "Ciel couvert (conditions idéales)", None),
                ("lumiere", "soleil", "Plein soleil", None),
                ("lumiere", "humide", "Feuillage ou sol mouillé", None)],
}

FORMS["rendement-echantillons"] = {
    "title": "Rendement par échantillons – PEPA Lab",
    "survey": ENTETE + [
        {"type": "text", "name": "pratique", "label": "Pratique ou modalité", "hint": "ex. bâche, BRF"},
        {"type": "text", "name": "culture", "label": "Culture"},
        {"type": "decimal", "name": "densite_plants_m2", "label": "Densité de plantation (plants par m²)", "required": "yes", "constraint": ". > 0"},
        {"type": "begin_repeat", "name": "echantillon", "label": "Échantillons (3 par planche)"},
        {"type": "integer", "name": "nb_plants", "label": "Nombre de plants dans l'échantillon", "default": "9", "constraint": ". > 0"},
        {"type": "decimal", "name": "masse_fraiche_g", "label": "Masse fraîche (g)", "required": "yes", "constraint": ". >= 0"},
        {"type": "end_repeat", "name": "echantillon"},
        {"type": "calculate", "name": "masse_par_plant_g", "calculation": "round(sum(${masse_fraiche_g}) div sum(${nb_plants}), 0)"},
        {"type": "calculate", "name": "rendement_kg_m2", "calculation": "round(${masse_par_plant_g} * ${densite_plants_m2} div 1000, 2)"},
        {"type": "note", "name": "affiche_rdt",
         "label": "Masse moyenne : **${masse_par_plant_g} g par plant**, soit environ **${rendement_kg_m2} kg/m²**"},
    ] + FIN,
    "choices": [],
}


def ecrire(dossier, cle, f):
    wb = Workbook()
    entete = Font(bold=True, color="FFFFFF")
    fond = PatternFill("solid", fgColor="4CAF50")
    ws = wb.active
    ws.title = "survey"
    ws.append(SURVEY_COLS)
    for row in f["survey"]:
        if row.get("type") == "image":
            row = dict(row, parameters="max-pixels=1600")
        ws.append([row.get(c, "") for c in SURVEY_COLS])
    wc = wb.create_sheet("choices")
    wc.append(["list_name", "name", "label"])
    for lst, name, label, _ in f["choices"]:
        wc.append([lst, name, label])
    wst = wb.create_sheet("settings")
    wst.append(["form_title", "form_id", "version"])
    wst.append([f["title"], "pepa_" + cle.replace("-", "_"), "2026-11-20"])
    for sh in (ws, wc, wst):
        for c in sh[1]:
            c.font, c.fill = entete, fond
        for col in sh.columns:
            sh.column_dimensions[col[0].column_letter].width = min(60, max(12, max(len(str(c.value or "")) for c in col) + 2))
    out = Path(dossier) / cle / "formulaire-kobo.xlsx"
    out.parent.mkdir(parents=True, exist_ok=True)
    wb.save(out)
    return out


if __name__ == "__main__":
    sortie = sys.argv[1] if len(sys.argv) > 1 else "formulaires"
    for cle, f in FORMS.items():
        print(ecrire(sortie, cle, f))
