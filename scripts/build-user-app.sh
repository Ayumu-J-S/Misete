#!/usr/bin/env bash
# Build a self-contained local distribution bundle.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$root_dir/dist/Misete.app"
archive="$root_dir/dist/Misete.dmg"
frameworks="$app/Contents/Frameworks"
helper="$app/Contents/Helpers/uxplay"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Misete.app can only be built on macOS." >&2
  exit 1
fi

"$root_dir/scripts/build-app.sh"
rm -rf "$frameworks"
mkdir -p "$frameworks"

declare -a pending=("$helper")

while (( ${#pending[@]} > 0 )); do
  binary="${pending[0]}"
  pending=("${pending[@]:1}")

  while IFS= read -r dependency; do
    [[ "$dependency" == /opt/homebrew/* ]] || continue
    name="$(basename "$dependency")"
    destination="$frameworks/$name"
    if [[ ! -e "$destination" ]]; then
      [[ -f "$dependency" ]] || { echo "Missing dependency: $dependency" >&2; exit 1; }
      cp -L "$dependency" "$destination"
      chmod u+w "$destination"
      pending+=("$destination")
    fi
    install_name_tool -change "$dependency" "@rpath/$name" "$binary"
  done < <(otool -L "$binary" | awk 'NR > 1 { print $1 }')
done

install_name_tool -add_rpath '@loader_path/../Frameworks' "$helper"

for library in "$frameworks"/*.dylib; do
  [[ -e "$library" ]] || continue
  while IFS= read -r dependency; do
    [[ "$dependency" == /opt/homebrew/* ]] || continue
    name="$(basename "$dependency")"
    destination="$frameworks/$name"
    if [[ ! -e "$destination" ]]; then
      [[ -f "$dependency" ]] || { echo "Missing dependency: $dependency" >&2; exit 1; }
      cp -L "$dependency" "$destination"
      chmod u+w "$destination"
    fi
    install_name_tool -change "$dependency" "@rpath/$name" "$library"
  done < <(otool -L "$library" | awk 'NR > 1 { print $1 }')
  install_name_tool -id "@rpath/$(basename "$library")" "$library"
  install_name_tool -add_rpath '@loader_path' "$library" 2>/dev/null || true
done

rm -f "$app/Contents/Resources/ThirdParty/UxPlay/RUNTIME-NOTICE.txt"
cat > "$app/Contents/Resources/ThirdParty/UxPlay/RUNTIME-NOTICE.txt" <<'EOF'
This distribution bundles the Homebrew runtime libraries required by UxPlay.
It is intended for use on macOS 14 or later.
EOF

codesign --force --sign - --timestamp=none "$helper"
for library in "$frameworks"/*.dylib; do
  [[ -e "$library" ]] || continue
  codesign --force --sign - --timestamp=none "$library"
done
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep --strict "$app"

staging_dir="$(mktemp -d "$root_dir/dist/.Misete-dmg.XXXXXX")"
mv "$app" "$staging_dir/Misete.app"
ln -s /Applications "$staging_dir/Applications"
rm -f "$archive"
hdiutil create -volname Misete -srcfolder "$staging_dir" -ov -format UDZO "$archive" >/dev/null
rm -rf "$staging_dir"

echo "Created self-contained $archive"