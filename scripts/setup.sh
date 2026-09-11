#!/usr/bin/env bash
# Prepare the macOS development dependencies used by Misete and its pinned UxPlay.
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Misete's receiver setup currently requires macOS." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it from https://brew.sh/, then rerun this script." >&2
  exit 1
fi

required=(cmake gstreamer libplist openssl@3 pkgconf)
missing=()
for formula in "${required[@]}"; do
  if ! brew list --versions "$formula" >/dev/null 2>&1; then
    missing+=("$formula")
  fi
done

if (( ${#missing[@]} > 0 )); then
  echo "Installing Homebrew dependencies: ${missing[*]}"
  brew install "${missing[@]}"
else
  echo "Homebrew dependencies are already installed."
fi

echo "macOS receiver prerequisites are ready. Run scripts/setup-receiver.sh to build UxPlay."
