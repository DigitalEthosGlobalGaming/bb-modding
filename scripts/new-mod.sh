#!/bin/sh
# Create a Rust mod from the template.
#   scripts/new-mod.sh <mod-id> "<Display Name>" [out-dir]
# e.g. scripts/new-mod.sh me.slow-lantern "Slow Lantern" ~/mods-src
set -e
ID="${1:?usage: new-mod.sh <mod-id> <Display Name> [out-dir]}"
NAME="${2:-$ID}"
SDK="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${3:-$PWD}/$ID"
CRATE="$(echo "$ID" | tr '.-' '__')"
TYPE="$(echo "$NAME" | sed 's/[^A-Za-z0-9]//g')"
[ -e "$OUT" ] && { echo "$OUT exists" >&2; exit 1; }
mkdir -p "$OUT"
cp -r "$SDK/templates/rust-mod/." "$OUT/"
find "$OUT" -type f | while read -r f; do
  sed -i "s|__ID__|$ID|g; s|__NAME__|$NAME|g; s|__CRATE__|$CRATE|g; s|__TYPE__|$TYPE|g; s|__SDK__|$SDK|g" "$f"
done
echo "Created $OUT"
echo "Build:  (cd $OUT && cargo build --release)"
echo "Install: copy mod.toml and target/release/$CRATE.dll into <game>/mods/$ID/"
