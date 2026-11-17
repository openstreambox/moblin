import json
import os
import plistlib
import re
import shutil
import subprocess
from pathlib import Path
from typing import Any
from xml.parsers.expat import ExpatError

DEFAULT_NAME = "Moblin"
DEFAULT_SCHEME = "moblin"
NAME = re.compile(r"(?<![A-Za-z])Moblin(?![A-Za-z])")
SCHEME = re.compile(r"(?<![A-Za-z])moblin://")


def rename_text(text: str, name: str, scheme: str) -> str:
    return SCHEME.sub(f"{scheme}://", NAME.sub(name, text))


def rename(value: Any, name: str, scheme: str) -> Any:
    if isinstance(value, str):
        return rename_text(value, name, scheme)
    if isinstance(value, list):
        return [rename(item, name, scheme) for item in value]
    if isinstance(value, dict):
        return {key: rename(item, name, scheme) for key, item in value.items()}
    return value


def load_plist(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {}
    try:
        with path.open("rb") as fin:
            data = plistlib.load(fin)
    except (plistlib.InvalidFileException, ExpatError):
        xml = subprocess.run(
            ["plutil", "-convert", "xml1", "-o", "-", str(path)], check=True, capture_output=True
        ).stdout
        data = plistlib.loads(xml)
    return data if isinstance(data, dict) else {}


def save_plist(path: Path, data: dict[str, Any]) -> None:
    with path.open("wb") as fout:
        plistlib.dump(data, fout, fmt=plistlib.PlistFormat.FMT_BINARY)


def catalog_keys(catalog: Path) -> list[str]:
    strings = json.loads(catalog.read_text(encoding="utf-8"))["strings"]
    return [key for key in strings if NAME.search(key) or SCHEME.search(key)]


def rename_tables(bundle: Path, keys: list[str], name: str, scheme: str) -> None:
    for lproj in sorted(bundle.glob("*.lproj")):
        strings = lproj / "Localizable.strings"
        table = rename(load_plist(strings), name, scheme)
        for key in keys:
            table.setdefault(key, rename_text(key, name, scheme))
        save_plist(strings, table)
        for other in ["Localizable.stringsdict", "InfoPlist.strings"]:
            path = lproj / other
            if path.exists():
                save_plist(path, rename(load_plist(path), name, scheme))


def rename_web_pages(bundle: Path, name: str, scheme: str) -> None:
    for path in sorted([*bundle.glob("*.html"), *bundle.glob("*.mjs")]):
        text = path.read_text(encoding="utf-8")
        renamed = rename_text(text, name, scheme)
        if renamed != text:
            path.write_text(renamed, encoding="utf-8")


def copy_resources(bundle: Path, resources: str) -> None:
    if not resources:
        return
    for path in sorted(Path(resources).iterdir()):
        if path.is_file():
            shutil.copyfile(path, bundle / path.name)


def main() -> None:
    name = os.environ.get("MOBLIN_DISPLAY_NAME", DEFAULT_NAME)
    scheme = os.environ.get("MOBLIN_URL_SCHEME", DEFAULT_SCHEME)
    if name == DEFAULT_NAME and scheme == DEFAULT_SCHEME:
        return
    bundle = Path(os.environ["TARGET_BUILD_DIR"]) / os.environ["UNLOCALIZED_RESOURCES_FOLDER_PATH"]
    keys = catalog_keys(Path(os.environ["SRCROOT"]) / "Common" / "Localizable.xcstrings")
    rename_tables(bundle, keys, name, scheme)
    rename_web_pages(bundle, name, scheme)
    copy_resources(bundle, os.environ.get("MOBLIN_BRAND_RESOURCES", ""))
    print(f"Renamed the app to {name} in {bundle}")


if __name__ == "__main__":
    main()
