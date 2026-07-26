#!/bin/bash

set -e

VERSION="1.11.0.6972"

TOOLS="./tools/compiler"

mkdir -p "$TOOLS"

cd "$TOOLS"

if [ -f spcomp64 ]; then
    echo "SourcePawn compiler already installed"
    exit 0
fi


echo "Downloading SourceMod compiler..."

wget \
https://sm.alliedmods.net/smdrop/1.11/sourcemod-${VERSION}-linux.tar.gz \
-O sourcemod.tar.gz


tar -xzf sourcemod.tar.gz


cp addons/sourcemod/scripting/spcomp64 .


chmod +x spcomp64

rm -rf addons
rm sourcemod.tar.gz


echo "Compiler installed:"
./spcomp64 --version
