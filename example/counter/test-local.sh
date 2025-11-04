#!/bin/bash
# Script to test local program-test changes
# Run this from the example/counter directory

set -e

# Setup override directory structure
echo "📁 Setting up override directory structure..."
mkdir -p overrides/packages/lamdera/program-test/3.0.0

# Copy source files from the root package
echo "📋 Copying source files from root package..."
rsync -av --delete ../../src/ overrides/packages/lamdera/program-test/3.0.0/src/
rsync -av ../../elm.json overrides/packages/lamdera/program-test/3.0.0/elm.json

echo "✅ Source files synced!"
echo ""
echo "🧹 Cleaning elm-stuff to force recompilation..."
rm -rf elm-stuff

echo ""
echo "🔧 Setting up overrides..."
./override.sh

echo ""
echo "🚀 Starting Lamdera live server with overrides..."
echo ""
echo "   📝 WORKFLOW:"
echo "   1. Edit files in the ROOT: ../../src/"
echo "   2. Re-run this script to sync changes and restart the server"
echo ""
echo "   OR edit directly in: overrides/packages/lamdera/program-test/3.0.0/src/"
echo "   (Lamdera will auto-reload those changes without restarting)"
echo ""

export LDEBUG=1
export EXPERIMENTAL=1
export LOVR=~/src/github.com/dillonkearns/program-test/example/counter/overrides

lamdera live
