#!/bin/bash

set -e

SPCOMP="${SPCOMP:-./tools/spcomp64}"

SOURCE="./sourcemod/scripting"
OUTPUT="./sourcemod/plugins"

plugins=(
    ss_afkbot
    ss_botmanager
    ss_botvoices
)

if [ ! -f "$SPCOMP" ]; then
    echo "ERROR: SourcePawn compiler not found:"
    echo "$SPCOMP"
    echo
    echo "Place spcomp64 in tools/"
    exit 1
fi


mkdir -p "$OUTPUT"


for plugin in "${plugins[@]}"
do
    echo "================================="
    echo "Compiling $plugin"
    echo "================================="

    "$SPCOMP" \
        "$SOURCE/$plugin.sp" \
        -o"$OUTPUT/$plugin.smx"

done


echo
echo "Build complete."
