"""Drop a render into the app's asset catalog.

    python3 tools/isorender/install.py --asset wall_shop_left

Replaces the PNG inside the matching `<asset>.imageset`, creating the imageset
(and a `Contents.json` in the repo's own shape) if it does not exist yet.

It also deletes the build's cached asset-catalog output, because replacing a
PNG in place does **not** invalidate that step: `xcodebuild` reports success,
ships the previous `Assets.car` byte for byte, and the simulator shows the old
art. A visual check done without this looks exactly like "the new art is
identical to the old" — which is the same thing you would see if the swap had
silently failed.
"""

import argparse
import json
import os
import shutil
import glob

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
CATALOG = os.path.join(REPO, "Resources", "Assets.xcassets")

CONTENTS_TEMPLATE = {
    "images": [{"filename": None, "idiom": "universal"}],
    "info": {"author": "xcode", "version": 1},
}


def find_imageset(catalog, name):
    matches = glob.glob(os.path.join(catalog, "**", f"{name}.imageset"), recursive=True)
    if len(matches) > 1:
        raise SystemExit(f"{name}.imageset exists in more than one place: {matches}")
    return matches[0] if matches else None


def create_imageset(catalog, name, group):
    path = os.path.join(catalog, group, f"{name}.imageset") if group else \
        os.path.join(catalog, f"{name}.imageset")
    os.makedirs(path, exist_ok=True)
    contents = json.loads(json.dumps(CONTENTS_TEMPLATE))
    contents["images"][0]["filename"] = f"{name}.png"
    with open(os.path.join(path, "Contents.json"), "w") as handle:
        json.dump(contents, handle, indent=2)
        handle.write("\n")
    return path


def target_filename(imageset, name):
    """Write to whatever filename the imageset already declares, so an
    existing `Contents.json` stays correct."""
    contents_path = os.path.join(imageset, "Contents.json")
    if os.path.exists(contents_path):
        with open(contents_path) as handle:
            images = json.load(handle).get("images", [])
        for image in images:
            if image.get("filename"):
                return image["filename"]
    return f"{name}.png"


def clear_asset_catalog_cache(derived_data):
    """Force the next build to recompile the catalog (see the module docstring)."""
    pattern = os.path.join(
        derived_data, "BomDongTycoon-*", "Build", "Intermediates.noindex",
        "BomDongTycoon.build", "*", "BomDongTycoon.build",
    )
    cleared = []
    for build_dir in glob.glob(pattern):
        for stale in ["assetcatalog_output"] + glob.glob(
            os.path.join(build_dir, "assetcatalog_dependencies*")
        ):
            path = stale if os.path.isabs(stale) else os.path.join(build_dir, stale)
            if os.path.exists(path):
                shutil.rmtree(path) if os.path.isdir(path) else os.remove(path)
                cleared.append(path)
    return cleared


def main():
    parser = argparse.ArgumentParser(prog="install.py")
    parser.add_argument("--asset", required=True)
    parser.add_argument("--out", default=os.path.join(HERE, "out"))
    parser.add_argument("--catalog", default=CATALOG)
    parser.add_argument("--group", default="shop",
                        help="catalog subfolder to create a new imageset in")
    parser.add_argument("--keep-build-cache", action="store_true",
                        help="skip clearing the cached asset-catalog output")
    args = parser.parse_args()

    source = os.path.join(args.out, f"{args.asset}.png")
    if not os.path.exists(source):
        raise SystemExit(f"no trimmed render at {source} — run render.sh first")

    imageset = find_imageset(args.catalog, args.asset)
    if imageset:
        action = "replaced"
    else:
        imageset = create_imageset(args.catalog, args.asset, args.group)
        action = "created"

    destination = os.path.join(imageset, target_filename(imageset, args.asset))
    shutil.copyfile(source, destination)
    print(f"{action} {os.path.relpath(destination, REPO)}")

    if not args.keep_build_cache:
        derived = os.path.expanduser("~/Library/Developer/Xcode/DerivedData")
        cleared = clear_asset_catalog_cache(derived)
        print(f"cleared {len(cleared)} cached asset-catalog artifact(s)"
              if cleared else "no cached asset-catalog output to clear")


if __name__ == "__main__":
    main()
