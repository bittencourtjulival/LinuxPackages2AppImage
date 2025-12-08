#!/bin/bash

# Linux2AppImage - Universal wrapper script
# Automatically detects package type and calls appropriate converter
# Usage: ./linux2appimage.sh <package.deb|package.rpm>

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to display messages
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

banner() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}   Linux2AppImage Converter${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

# Check if package file was provided
if [ $# -eq 0 ]; then
    banner
    echo "Usage: $0 <package.deb|package.rpm>"
    echo ""
    echo "Supported formats:"
    echo "  • .deb (Debian/Ubuntu packages)"
    echo "  • .rpm (Fedora/RHEL/SUSE packages)"
    echo ""
    echo "Examples:"
    echo "  $0 firefox_130.0-1_amd64.deb"
    echo "  $0 chromium-130.0-1.x86_64.rpm"
    exit 1
fi

PACKAGE_FILE="$1"

# Check if file exists
if [ ! -f "$PACKAGE_FILE" ]; then
    error "File not found: $PACKAGE_FILE"
fi

banner

# Detect package type
info "Detecting package type..."

PACKAGE_TYPE=""
CONVERTER_SCRIPT=""

if [[ "$PACKAGE_FILE" == *.deb ]]; then
    PACKAGE_TYPE="DEB"
    CONVERTER_SCRIPT="deb2appimage.sh"
elif [[ "$PACKAGE_FILE" == *.rpm ]]; then
    PACKAGE_TYPE="RPM"
    CONVERTER_SCRIPT="rpm2appimage.sh"
else
    error "Unsupported package format. Only .deb and .rpm are supported."
fi

info "Package type: $PACKAGE_TYPE"
info "Using converter: $CONVERTER_SCRIPT"
echo ""

# Check if converter script exists
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONVERTER_PATH="$SCRIPT_DIR/$CONVERTER_SCRIPT"

if [ ! -f "$CONVERTER_PATH" ]; then
    error "Converter script not found: $CONVERTER_PATH"
fi

# Check if converter script is executable
if [ ! -x "$CONVERTER_PATH" ]; then
    info "Making converter script executable..."
    chmod +x "$CONVERTER_PATH"
fi

# Call the appropriate converter
info "Starting conversion process..."
echo ""
"$CONVERTER_PATH" "$PACKAGE_FILE"

# Check exit status
if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Conversion completed successfully!${NC}"
else
    echo ""
    error "Conversion failed. Check the errors above."
fi
