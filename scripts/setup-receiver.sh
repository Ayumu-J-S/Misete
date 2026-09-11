#!/usr/bin/env bash
# Fetch and compile the exact UxPlay source used by Misete.
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
deps_dir="$root_dir/.deps"
source_dir="$deps_dir/uxplay-source"
build_dir="$deps_dir/uxplay-build"
install_dir="$deps_dir/uxplay"
repository="https://github.com/FDH2/UxPlay.git"
revision="9bebe1268671aeb76d0fd0e10621c05b5175505e"
patch_file="$root_dir/Resources/Patches/uxplay-stdout-flush.patch"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "UxPlay receiver setup is currently supported on macOS only." >&2
  exit 1
fi

for command in git cmake brew patch; do
  if ! command -v "$command" >/dev/null 2>&1; then
    echo "Missing $command. Run scripts/setup.sh first." >&2
    exit 1
  fi
done

if [[ ! -f "$patch_file" ]]; then
  echo "Missing required UxPlay patch: $patch_file" >&2
  exit 1
fi
patch_sha256="$(shasum -a 256 "$patch_file" | awk '{print $1}')"

for formula in gstreamer libplist openssl@3 pkgconf; do
  if ! brew list --versions "$formula" >/dev/null 2>&1; then
    echo "Missing Homebrew formula '$formula'. Run scripts/setup.sh first." >&2
    exit 1
  fi
done

mkdir -p "$deps_dir"
if [[ ! -d "$source_dir/.git" ]]; then
  if [[ -e "$source_dir" ]]; then
    echo "Expected a git checkout at $source_dir; refusing to replace existing files." >&2
    exit 1
  fi
  git clone "$repository" "$source_dir"
fi

origin_url="$(git -C "$source_dir" remote get-url origin 2>/dev/null || true)"
if [[ "$origin_url" != "$repository" ]]; then
  echo "Unexpected UxPlay origin: $origin_url" >&2
  echo "Expected: $repository" >&2
  exit 1
fi

git -C "$source_dir" fetch --quiet origin "$revision"
if [[ -n "$(git -C "$source_dir" ls-files --others --exclude-standard)" ]] || \
   ! git -C "$source_dir" diff --quiet --cached; then
  echo "UxPlay source checkout has untracked or staged changes; refusing to overwrite provenance." >&2
  exit 1
fi

changed_files="$(git -C "$source_dir" diff --name-only)"
if [[ -z "$changed_files" ]]; then
  git -C "$source_dir" checkout --quiet --detach "$revision"
  git -C "$source_dir" apply --check "$patch_file"
  git -C "$source_dir" apply "$patch_file"
elif [[ "$changed_files" != "uxplay.cpp" ]]; then
  echo "UxPlay source checkout has unexpected local changes; refusing to overwrite provenance." >&2
  exit 1
fi
actual_revision="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_revision" != "$revision" ]]; then
  echo "UxPlay revision verification failed: expected $revision, got $actual_revision" >&2
  exit 1
fi

expected_dir="$(mktemp -d "$deps_dir/.uxplay-expected.XXXXXX")"
cleanup_expected() {
  rm -rf "$expected_dir"
}
trap cleanup_expected EXIT
git -C "$source_dir" show "$revision:uxplay.cpp" > "$expected_dir/uxplay.cpp"
if ! (cd "$expected_dir" && patch --batch --silent -p1 < "$patch_file") || \
   ! cmp -s "$source_dir/uxplay.cpp" "$expected_dir/uxplay.cpp"; then
  echo "UxPlay source differs from the exact pinned source plus stdout-flush patch." >&2
  exit 1
fi

brew_prefix="$(brew --prefix)"
cmake -S "$source_dir" -B "$build_dir" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$install_dir" \
  -DOPENSSL_ROOT_DIR="$brew_prefix/opt/openssl@3" \
  -DGSTREAMER_ROOT_DIR="$brew_prefix" \
  -DUSE_DNS_SD=ON
cmake --build "$build_dir" --config Release --parallel
cmake --install "$build_dir" --config Release

if [[ ! -x "$install_dir/bin/uxplay" ]]; then
  echo "UxPlay install did not produce $install_dir/bin/uxplay" >&2
  exit 1
fi

mkdir -p "$install_dir/licenses"
cp "$source_dir/LICENSE" "$install_dir/licenses/UxPlay-GPL-3.0.txt"
cat > "$install_dir/SOURCE.txt" <<EOF
Component: UxPlay
Repository: $repository
Revision: $revision
Patch: Resources/Patches/uxplay-stdout-flush.patch (fflush(stdout) after UxPlay log lines)
Patch-SHA256: $patch_sha256
License: GPL-3.0-or-later; see licenses/UxPlay-GPL-3.0.txt
Built locally by scripts/setup-receiver.sh
EOF

echo "Built UxPlay $actual_revision at $install_dir/bin/uxplay"
