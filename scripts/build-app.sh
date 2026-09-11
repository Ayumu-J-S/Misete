#!/usr/bin/env bash
# Assemble a local developer .app bundle. It intentionally uses Homebrew dylibs.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
receiver="$root_dir/.deps/uxplay/bin/uxplay"
bundle="$root_dir/dist/Misete.app"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Misete.app can only be built on macOS." >&2
  exit 1
fi
if [[ ! -x "$receiver" ]]; then
  echo "Missing pinned UxPlay receiver at $receiver. Run scripts/setup-receiver.sh first." >&2
  exit 1
fi

cd "$root_dir"
swift build -c release
binary_dir="$(swift build -c release --show-bin-path)"
app_binary="$binary_dir/Misete"
if [[ ! -x "$app_binary" ]]; then
  echo "Swift build did not produce $app_binary" >&2
  exit 1
fi

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Helpers" "$bundle/Contents/Resources/ThirdParty/UxPlay"
cp "$app_binary" "$bundle/Contents/MacOS/Misete"
cp "$receiver" "$bundle/Contents/Helpers/uxplay"
cp "$root_dir/Resources/Info.plist" "$bundle/Contents/Info.plist"
cp "$root_dir/.deps/uxplay/licenses/UxPlay-GPL-3.0.txt" "$bundle/Contents/Resources/ThirdParty/UxPlay/LICENSE"
cp "$root_dir/.deps/uxplay/SOURCE.txt" "$bundle/Contents/Resources/ThirdParty/UxPlay/SOURCE.txt"

# This is a developer bundle, not a redistributable package. UxPlay and its
# dependencies resolve from the developer's Homebrew prefix at runtime.
cat > "$bundle/Contents/Resources/ThirdParty/UxPlay/RUNTIME-NOTICE.txt" <<EOF
This local developer build depends on Homebrew runtime libraries.
Homebrew prefix at build time: $(brew --prefix)
It is not a standalone distributable application bundle.
EOF

codesign --force --sign - --timestamp=none "$bundle/Contents/Helpers/uxplay"
codesign --force --sign - --timestamp=none "$bundle"
codesign --verify --deep --strict "$bundle"

echo "Created $bundle"
