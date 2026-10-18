#!/bin/sh
# Build this mod and put it in bbport's code-mod folder (Linux / MSYS2 shell).
#   ./dev.sh [--watch] [--debug] [mods-dir]     mods-dir default: $BB_CODEMODS_DIR or $BBPORT_DIR/bbmods
set -e
cd "$(dirname "$0")"
WATCH=0; PROFILE=release; MODS=${BB_CODEMODS_DIR:-${BBPORT_DIR:+$BBPORT_DIR/bbmods}}
for a in "$@"; do case $a in --watch) WATCH=1;; --debug) PROFILE=debug;; *) MODS=$a;; esac; done
[ -n "$MODS" ] || { echo "pass the bbmods folder or set BBPORT_DIR" >&2; exit 1; }
field() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"\([^\"]*\)\".*/\1/p" mod.toml | head -1; }
ID=$(field id); DLL=$(field dll)
deploy() {
    if [ $PROFILE = release ]; then cargo build --release || { echo "build failed"; return; }
    else cargo build || { echo "build failed"; return; }; fi
    mkdir -p "$MODS/$ID"
    # Windows targets name it $DLL; on Linux cargo makes lib<name>.so: copy it under the manifest's name.
    SRC=target/$PROFILE/$DLL; [ -f "$SRC" ] || SRC=target/$PROFILE/lib${DLL%.dll}.so
    cp "$SRC" "$MODS/$ID/$DLL"; cp mod.toml "$MODS/$ID/"
    for x in *.xml; do [ -f "$x" ] && cp "$x" "$MODS/$ID/"; done
    [ -d dvdroot_ps4 ] && cp -r dvdroot_ps4 "$MODS/$ID/"
    echo "$(date +%T) deployed $ID -> $MODS/$ID"
}
stamp() { find src mod.toml Cargo.toml -type f -newer "$1" 2>/dev/null | head -1; }
deploy
[ $WATCH = 1 ] || exit 0
echo "watching (Ctrl+C to stop)"
MARK=$(mktemp); while :; do sleep 0.5; if [ -n "$(stamp "$MARK")" ]; then touch "$MARK"; sleep 0.2; deploy; fi; done
