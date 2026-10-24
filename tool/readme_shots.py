"""README-Bilder verkleinern: build/readme_shots/*.png -> docs/screenshots/*.jpg

Erst die Bilder aufnehmen (siehe integration_test/readme_shots_test.dart), dann:
    python tool/readme_shots.py
"""

import pathlib

from PIL import Image

SOURCE = pathlib.Path("build/readme_shots")
TARGET = pathlib.Path("docs/screenshots")
WIDTH = 1800

TARGET.mkdir(parents=True, exist_ok=True)
for png in sorted(SOURCE.glob("*.png")):
    image = Image.open(png).convert("RGB")
    if image.width > WIDTH:
        image = image.resize((WIDTH, round(image.height * WIDTH / image.width)), Image.LANCZOS)
    out = TARGET / f"{png.stem}.jpg"
    image.save(out, "JPEG", quality=88, optimize=True, progressive=True)
    print(f"{out}  {out.stat().st_size // 1024} KB")
