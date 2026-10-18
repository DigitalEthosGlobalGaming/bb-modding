#!/bin/sh
# Archive committed source only: scripts/pack.sh [out.zip]
set -e
cd "$(dirname "$0")/.."
OUT="${1:-bbmod.zip}"
git archive --format=zip --output="$OUT" HEAD
