from pathlib import Path
from PIL import Image

ICON_DIR = Path(__file__).resolve().parents[1] / "Budgetify" / "Assets.xcassets" / "AppIcon.appiconset"

for filename in ("AppIcon-Light.png", "AppIcon-Dark.png"):
    path = ICON_DIR / filename
    with Image.open(path) as image:
        normalized = image.convert("RGBA").resize((1024, 1024), Image.Resampling.LANCZOS)
        normalized.save(path, format="PNG", optimize=True)
        print(f"{path}: size={normalized.size}, mode={normalized.mode}")
        if normalized.size != (1024, 1024):
            raise SystemExit(f"wrong size: {path}")
