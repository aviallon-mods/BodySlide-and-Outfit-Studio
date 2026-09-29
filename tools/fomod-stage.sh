#!/usr/bin/env bash
# Stage the BodySlide / Outfit Studio payload the FOMOD zip is assembled from.
#
# Inputs:
#   build/fomod/RelWithDebInfo/BodySlide.exe, OutfitStudio.exe   (tools/fomod-build.sh)
#   the repo's tracked res/, lang/ and root XML config files
#
# Output: stage/<install root>, mirroring the layout of the windows
# package (.github/workflows/cmake-release.yml's "Package artifacts" step)
# exactly, except:
#   * the empty SliderSets/Automations/... data directories are not carried
#     (the packaged zip is a list of files; the tool creates those directories
#     when it runs);
#   * two res/ notes are skipped because the shared packager's archive-path
#     gate rejects spaces in zip entry names and their names contain spaces:
#       res/Maya FBX Skyrim Fix.txt, res/Maya FBX FO4 Fix.txt
# (kept in the package since modforge's packager accepts spaces in names;
#     They are modder notes for exporting FBX from Maya, not runtime files.
#     (modforge tools/package_fomod.py: `hostile archive path` for names its
#     [A-Za-z0-9._\-/] class does not cover.)
#
# The closing assertion refuses to continue when the staged tree carries a file
# the committed fomod-package.toml does not claim (a file added to res/ or
# lang/ turns the run red instead of silently missing from the zip), and
# package_fomod.py fails the other way round, on a claimed file that staging
# did not produce.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT="build/fomod/RelWithDebInfo"
[ -f "$OUT/BodySlide.exe" ] || { echo "::error::$OUT/BodySlide.exe missing - run tools/fomod-build.sh first"; exit 1; }
[ -f "$OUT/OutfitStudio.exe" ] || { echo "::error::$OUT/OutfitStudio.exe missing - run tools/fomod-build.sh first"; exit 1; }

# Version from the git tags, resolved exactly like .github/appimage/
# make-appimage.sh does. The shared checkout is shallow and tagless, so widen
# the history first when we can.
if [ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo true)" = "true" ]; then
  git fetch --unshallow --tags -q 2>/dev/null || git fetch --tags -q 2>/dev/null || true
else
  git fetch --tags -q 2>/dev/null || true
fi
version=$(git describe --tags --always 2>/dev/null || true)
version="${version#v}"
[ -n "$version" ] || version=$(git rev-parse --short HEAD)
printf '%s\n' "$version" > fomod-version.txt
echo "version from git describe: $version"

rm -rf stage
mkdir -p stage
cp "$OUT/BodySlide.exe" "$OUT/OutfitStudio.exe" stage/
cp BodySlide.xml BuildSelection.xml Config.xml OutfitStudio.xml RefTemplates.xml stage/
cp -a res lang stage/

echo "staged $(find stage -type f | wc -l) files"

python3 - <<'EOF'
import sys
import tomllib
from pathlib import Path

spec = tomllib.loads(Path("fomod-package.toml").read_text())
claimed = {i["src"] for i in spec["files"] if i["src"].startswith("stage/")}
staged = {p.as_posix() for p in Path("stage").rglob("*") if p.is_file()}
unclaimed = sorted(staged - claimed)
if unclaimed:
    print("::error::staged payload files not claimed by fomod-package.toml "
          "(they would silently miss from the zip):")
    for f in unclaimed:
        print(f"  {f}")
    sys.exit(1)
print(f"fomod-package.toml claims all {len(staged)} staged payload files")
EOF
