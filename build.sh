#!/bin/bash

# Build script for Koha PLR Plugin
# Creates a .kpz file (renamed .tar.gz) for installation in Koha

set -e

# Extract version from the main plugin file
VERSION=$(grep "our \$VERSION = " Koha/Plugin/Com/OpenFifth/PLR.pm | sed "s/.*'\(.*\)'.*/\1/")

if [ -z "$VERSION" ]; then
    echo "Error: Could not find version in plugin file"
    exit 1
fi

OUTPUT_FILE="koha-plugin-plr-v${VERSION}.kpz"

echo "Building Koha PLR Plugin v${VERSION}..."

# Create temporary build directory
BUILD_DIR="build_temp"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Copy plugin files to build directory
echo "  Copying files..."
cp -r Koha "$BUILD_DIR/"
cp README.md "$BUILD_DIR/"

# Create tar.gz archive and rename to .kpz
echo "  Creating archive..."
cd "$BUILD_DIR"
tar czf "../${OUTPUT_FILE}" *
cd ..

# Clean up build directory
rm -rf "$BUILD_DIR"

echo ""
echo "Success! Created ${OUTPUT_FILE}"
echo ""
echo "Installation:"
echo "  1. Go to Koha > Tools > Plugins"
echo "  2. Click 'Upload plugin'"
echo "  3. Select ${OUTPUT_FILE}"
echo "  4. Click 'Upload'"
echo ""
