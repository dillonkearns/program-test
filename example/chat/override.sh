#!/bin/bash
# Script to set up local Lamdera package overrides
#
# Usage from your lamdera app directory:
#   ./override.sh <package-root>
#
# Example: ./override.sh ../../

set -e

if [ $# -eq 0 ]; then
  echo "Error: Package root directory required"
  echo "Usage: $0 <package-root>"
  exit 1
fi

PACKAGE_ROOT="$1"
APP_ROOT="$(pwd)"

# Verify package root exists
if [ ! -f "$PACKAGE_ROOT/elm.json" ]; then
  echo "Error: elm.json not found at $PACKAGE_ROOT"
  exit 1
fi

# Extract package info using jq
PACKAGE_NAME=$(jq -r '.name' "$PACKAGE_ROOT/elm.json")

if [ -z "$PACKAGE_NAME" ] || [ "$PACKAGE_NAME" = "null" ]; then
  echo "Error: Could not read package name from $PACKAGE_ROOT/elm.json"
  exit 1
fi

# Get the version that the app is requesting (not the package's actual version)
VERSION=$(jq -r ".dependencies.direct[\"$PACKAGE_NAME\"] // .dependencies.indirect[\"$PACKAGE_NAME\"]" "$APP_ROOT/elm.json")

if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  echo "Error: Package $PACKAGE_NAME not found in $APP_ROOT/elm.json dependencies"
  exit 1
fi

# Split package name into author/package
AUTHOR=$(echo "$PACKAGE_NAME" | cut -d'/' -f1)
PACKAGE=$(echo "$PACKAGE_NAME" | cut -d'/' -f2)

echo "Setting up override for $PACKAGE_NAME $VERSION"
echo ""

# Setup override directory structure
OVERRIDE_BASE="$APP_ROOT/overrides/packages/$AUTHOR/$PACKAGE"
OVERRIDE_DIR="$OVERRIDE_BASE/$VERSION"

mkdir -p "$OVERRIDE_DIR"

# Copy source files
echo "Syncing source files..."
rsync -a --delete "$PACKAGE_ROOT/src/" "$OVERRIDE_DIR/src/"
rsync -a "$PACKAGE_ROOT/elm.json" "$OVERRIDE_DIR/elm.json"

# Build the override package
echo "Building override package..."
rm -rf "$OVERRIDE_DIR/elm-stuff"
(cd "$OVERRIDE_DIR" && lamdera make)
(cd "$OVERRIDE_BASE" && rm -f pack.zip && zip -r pack.zip "$VERSION/" -x "*/.git/*" -x "*/elm-stuff/*" > /dev/null)

# Generate endpoint.json
HASH=$(cd "$OVERRIDE_BASE" && shasum pack.zip | cut -d' ' -f1)
(cd "$OVERRIDE_BASE" && echo "{\"url\":\"https://static.lamdera.com/r/$AUTHOR/$PACKAGE/pack.zip\",\"hash\":\"$HASH\"}" > "$VERSION/endpoint.json")

# Remove override's elm-stuff to avoid dependency conflicts
rm -rf "$OVERRIDE_DIR/elm-stuff"

# Clean caches - only remove the specific package we're overriding
echo "Cleaning caches..."
ELM_HOME="${ELM_HOME:-$HOME/.elm}"
PACKAGE_CACHE="$ELM_HOME/0.19.1/packages/$AUTHOR/$PACKAGE"
if [ -d "$PACKAGE_CACHE" ]; then
  echo "Removing cached package: $PACKAGE_CACHE"
  rm -rf "$PACKAGE_CACHE"
fi
rm -rf elm-stuff

LDEBUG=1 EXPERIMENTAL=1 LOVR="$APP_ROOT/overrides" lamdera live
