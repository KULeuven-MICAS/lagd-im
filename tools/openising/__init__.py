from pathlib import Path
import os

current_dir = Path(os.path.dirname(os.path.realpath(__file__)))
# Set the correct top path
toppath = current_dir / "openising"
os.environ["TOP"] = str(toppath)