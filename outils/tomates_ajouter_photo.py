"""Ajoute une photo à une variété du conservatoire de tomates.

Usage (depuis la racine du dépôt) :
  python3 outils/tomates_ajouter_photo.py <id_variete> <image.jpg> [type_photo] [légende]
  ex. python3 outils/tomates_ajouter_photo.py 27 ~/Desktop/IMG_1234.jpg tomate "Grappe à maturité"

type_photo : tomate (photo principale de la carte), plant, coupe… — la première photo
« tomate » ou « fruit » d'une variété est utilisée sur sa carte.
La photo est redressée, réduite à 1200 px et enregistrée dans tomates/photos/<id>/.
"""
import csv, sys, uuid
from pathlib import Path
from PIL import Image, ImageOps

if len(sys.argv) < 3:
    sys.exit(__doc__)
vid, src = sys.argv[1], Path(sys.argv[2]).expanduser()
type_photo = sys.argv[3] if len(sys.argv) > 3 else "tomate"
legende = sys.argv[4] if len(sys.argv) > 4 else ""

ids = {r["id"] for r in csv.DictReader(open("tomates/varietes.csv", encoding="utf-8"))}
if vid not in ids:
    sys.exit(f"Aucune variété avec l'id {vid} dans tomates/varietes.csv")

dst = Path("tomates/photos") / vid / f"{uuid.uuid4()}.jpg"
dst.parent.mkdir(parents=True, exist_ok=True)
im = ImageOps.exif_transpose(Image.open(src)).convert("RGB")
im.thumbnail((1200, 1200))
im.save(dst, "JPEG", quality=82, optimize=True)

with open("tomates/photos.csv", "a", newline="", encoding="utf-8") as f:
    csv.writer(f).writerow([vid, dst.relative_to("tomates").as_posix(), legende, type_photo])
print("Photo ajoutée :", dst)
