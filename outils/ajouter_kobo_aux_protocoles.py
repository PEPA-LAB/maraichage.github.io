"""Ajoute le bloc KoboToolbox dans la section « Fiche de relevé » de chaque protocole
qui possède un formulaire-kobo.xlsx, et publie les .xlsx avec le site.
À lancer depuis la racine du dépôt : python3 outils/ajouter_kobo_aux_protocoles.py"""
from pathlib import Path
import re

INCLUDE = "{{< include /_includes/kobo.qmd >}}"
for qmd in sorted(Path("protocoles").glob("*/index.qmd")):
    if qmd.parent.name.startswith("_") or not (qmd.parent / "formulaire-kobo.xlsx").exists():
        continue
    s = qmd.read_text(encoding="utf-8")
    if INCLUDE in s:
        print("déjà fait :", qmd); continue
    m = re.search(r"\n## Fiche de relevé\n(.*?)(?=\n## )", s, flags=re.S)
    if not m:
        print("section « Fiche de relevé » introuvable :", qmd); continue
    s = s[:m.end()] + "\n" + INCLUDE + "\n" + s[m.end():]
    qmd.write_text(s, encoding="utf-8"); print("ajouté :", qmd)

q = Path("_quarto.yml"); s = q.read_text(encoding="utf-8")
if "protocoles/**/*.xlsx" not in s:
    s = s.replace('    - "protocoles/**/*.csv"', '    - "protocoles/**/*.csv"\n    - "protocoles/**/*.xlsx"   # formulaires KoboToolbox', 1)
    q.write_text(s, encoding="utf-8"); print("_quarto.yml : .xlsx ajoutés aux ressources")
