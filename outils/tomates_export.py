"""Exporte le conservatoire de tomates vers les fichiers statiques du site.

Source : la base SQLite de l'application Shiny (ou, à défaut, data_tomates.xlsx).
Sortie (dans le dépôt) :
  tomates/varietes.csv   ← table des variétés, SOURCE À ÉDITER ENSUITE (GitHub web ou tableur)
  tomates/photos.csv     ← une ligne par photo (variete_id, fichier, legende, type_photo)
  tomates/varietes.xlsx  ← même contenu, pour téléchargement
  tomates/photos/{id}/   ← photos redimensionnées (1200 px max)
  tomates/corrections.csv ← journal des corrections d'orthographe appliquées

Usage (depuis la racine du dépôt), pour l'import initial seulement :
  python3 outils/tomates_export.py "<dossier du projet Shiny>" [--ecraser]
Une fois le site en ligne, c'est tomates/varietes.csv qu'on modifie : relancer ce script
écraserait ces modifications, d'où l'option --ecraser obligatoire.
Les fichiers sources ne sont jamais modifiés.
"""
import csv, re, sqlite3, sys, shutil
from pathlib import Path

ARGS = [a for a in sys.argv[1:] if not a.startswith("--")]
SRC = Path(ARGS[0]) if ARGS else Path("../conservatoire tomate")
DEST = Path("tomates")
TAILLE_MAX = 1200

COLONNES = ["id", "cultivar", "maturite", "calibre", "type", "forme", "couleur", "bouche",
            "croissance", "rendement", "sensibilite", "plein_champs", "date_graines",
            "multiplication_2025", "multiplication_2026", "origine", "utilisation", "remarque"]

# Corrections d'orthographe uniquement (pas de changement de sens). Clé = valeur exacte d'origine.
CORRECTIONS = {
    "maturite": {"hative": "hâtive", "haâtive": "hâtive"},
    "type": {"petit": "petite", "gros": "grosse", "coktail": "cocktail", "beefsteack": "beefsteak"},
    "croissance": {"indeterminée": "indéterminée", "inderterminée": "indéterminée"},
    "rendement": {"élevée": "élevé"},
    "origine": {"inconnue": "Inconnue", "Royaume Uni": "Royaume-Uni", "Pays-bas": "Pays-Bas",
                "République tchéque": "République tchèque"},
    "sensibilite": {"resiste froid": "résiste au froid"},
}
# Corrections de mots à l'intérieur des listes (forme, couleur)
MOTS = {"rondee": "ronde", "applatie": "aplatie", "cotelée": "côtelée", "cotelé": "côtelée",
        "coordiforme": "cordiforme", "légerement": "légèrement"}


def corriger(col, val, journal, vid):
    if val is None or str(val).strip() == "":
        return ""
    v0 = str(val).strip()
    v = CORRECTIONS.get(col, {}).get(v0, v0)
    if col in ("forme", "couleur"):
        v = v.replace("rouge/bordeau", "rouge, bordeaux")
        v = re.sub(r"[\wàâäéèêëîïôöùûüç]+", lambda m: MOTS.get(m.group(0), m.group(0)), v)
    if v != v0:
        journal.append({"id": vid, "colonne": col, "avant": v0, "apres": v})
    return v


def lire_sqlite(db):
    c = sqlite3.connect(db)
    c.row_factory = sqlite3.Row
    v = [dict(r) for r in c.execute("SELECT * FROM varietes ORDER BY id")]
    p = [dict(r) for r in c.execute("SELECT * FROM photos ORDER BY variete_id")]
    return v, p


def main():
    if (DEST / "varietes.csv").exists() and "--ecraser" not in sys.argv:
        sys.exit("tomates/varietes.csv existe déjà : ajoutez --ecraser pour le remplacer (les modifications faites depuis seront perdues).")
    db = SRC / "conservatoire_demo.sqlite"
    varietes, photos = lire_sqlite(db)
    journal = []
    DEST.mkdir(exist_ok=True)
    lignes = []
    for r in varietes:
        out = {}
        for col in COLONNES:
            val = r.get(col)
            if col in ("multiplication_2025", "multiplication_2026"):
                out[col] = "oui" if val in (1, "1", "x", "X") else "non"
            elif col == "calibre":
                out[col] = "" if val is None else f"{float(val):.2f}".rstrip("0").rstrip(".")
            elif col == "id":
                out[col] = int(val)
            else:
                out[col] = corriger(col, val, journal, r["id"])
        lignes.append(out)
    with open(DEST / "varietes.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=COLONNES); w.writeheader(); w.writerows(lignes)

    # Photos : copie + redimensionnement
    from PIL import Image, ImageOps
    sortie_photos = []
    for p in photos:
        src = SRC / "www" / p["chemin_fichier"]
        if not src.exists():
            print("photo introuvable :", src); continue
        dst = DEST / "photos" / str(p["variete_id"]) / (Path(p["chemin_fichier"]).stem + ".jpg")
        dst.parent.mkdir(parents=True, exist_ok=True)
        im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
        im.thumbnail((TAILLE_MAX, TAILLE_MAX))
        im.save(dst, "JPEG", quality=82, optimize=True)
        sortie_photos.append({"variete_id": p["variete_id"], "fichier": dst.relative_to(DEST).as_posix(),
                              "legende": p.get("legende") or "", "type_photo": p.get("type_photo") or ""})
    with open(DEST / "photos.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["variete_id", "fichier", "legende", "type_photo"]); w.writeheader(); w.writerows(sortie_photos)

    with open(DEST / "corrections.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=["id", "colonne", "avant", "apres"]); w.writeheader(); w.writerows(journal)

    # Version Excel pour téléchargement
    from openpyxl import Workbook
    wb = Workbook(); ws = wb.active; ws.title = "varietes"
    ws.append(COLONNES)
    for l in lignes: ws.append([l[c] for c in COLONNES])
    wb.save(DEST / "varietes.xlsx")

    # Logos
    (DEST / "logos").mkdir(exist_ok=True)
    for f in (SRC / "www" / "logo").glob("*"):
        shutil.copy2(f, DEST / "logos" / f.name)
    print(f"{len(lignes)} variétés, {len(sortie_photos)} photos, {len(journal)} corrections")


if __name__ == "__main__":
    main()
