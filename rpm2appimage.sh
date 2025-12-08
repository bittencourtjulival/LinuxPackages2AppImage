#!/bin/bash

# Script to convert RPM packages to AppImage
# Usage: ./rpm2appimage.sh package.rpm

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if RPM file was provided
if [ $# -eq 0 ]; then
    error "Usage: $0 <package.rpm>"
fi

RPM_FILE="$1"

# Check if file exists
if [ ! -f "$RPM_FILE" ]; then
    error "File not found: $RPM_FILE"
fi

# Check if it's an RPM file
if [[ "$RPM_FILE" != *.rpm ]]; then
    error "File is not an RPM package: $RPM_FILE"
fi

# Check for RPM extraction tools
if ! command -v rpmextract.sh &> /dev/null && ! command -v rpm2cpio &> /dev/null; then
    error "RPM extraction tool not found. Install with: apt install rpm2cpio OR dnf install rpm OR pacman -S rpmextract"
fi

# Check for other dependencies
for cmd in cpio wget; do
    if ! command -v $cmd &> /dev/null; then
        error "Dependency not found: $cmd"
    fi
done

# Check if rpm command is available for metadata extraction
if ! command -v rpm &> /dev/null; then
    warn "rpm command not found. Package metadata will be extracted from filename."
fi

# Extract package information
info "Extracting package information..."

if command -v rpm &> /dev/null; then
    PKG_NAME=$(rpm -qp --queryformat '%{NAME}' "$RPM_FILE" 2>/dev/null)
    PKG_VERSION=$(rpm -qp --queryformat '%{VERSION}-%{RELEASE}' "$RPM_FILE" 2>/dev/null)
    PKG_ARCH=$(rpm -qp --queryformat '%{ARCH}' "$RPM_FILE" 2>/dev/null)
else
    # Fallback: extract from filename
    BASENAME=$(basename "$RPM_FILE" .rpm)
    PKG_NAME=$(echo "$BASENAME" | sed 's/-[0-9].*//')
    PKG_VERSION=$(echo "$BASENAME" | grep -oP '\d+[\d\.\-]*' | head -1)
    PKG_ARCH=$(echo "$BASENAME" | grep -oP '(x86_64|i686|i386|aarch64|armv7hl|noarch)' | tail -1)
    
    # Defaults if extraction fails
    [ -z "$PKG_NAME" ] && PKG_NAME=$(echo "$BASENAME" | cut -d'-' -f1)
    [ -z "$PKG_VERSION" ] && PKG_VERSION="1.0"
    [ -z "$PKG_ARCH" ] && PKG_ARCH="x86_64"
    
    info "Parsed from filename - name: $PKG_NAME, version: $PKG_VERSION, arch: $PKG_ARCH"
fi

info "Package: $PKG_NAME"
info "Version: $PKG_VERSION"
info "Architecture: $PKG_ARCH"

# Create work directory
WORK_DIR="${PKG_NAME}.AppDir"
info "Creating work directory: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Extract RPM contents
info "Extracting package contents..."
cd "$WORK_DIR"

if command -v rpmextract.sh &> /dev/null; then
    info "Using rpmextract.sh (Arch Linux)"
    rpmextract.sh "$OLDPWD/$RPM_FILE" 2>/dev/null
elif command -v rpm2cpio &> /dev/null; then
    info "Using rpm2cpio + cpio"
    rpm2cpio "$OLDPWD/$RPM_FILE" | cpio -idmv 2>/dev/null
else
    cd "$OLDPWD"
    error "No RPM extraction tool available"
fi

cd "$OLDPWD"

# Look for main executable
info "Looking for main executable..."
EXEC_PATH=""
EXEC_REL_PATH=""

# Search in /usr/bin
if [ -d "$WORK_DIR/usr/bin" ]; then
    EXEC_PATH=$(find "$WORK_DIR/usr/bin" -type f -executable 2>/dev/null | head -n 1)
fi

# Search in /usr/sbin
if [ -z "$EXEC_PATH" ] && [ -d "$WORK_DIR/usr/sbin" ]; then
    EXEC_PATH=$(find "$WORK_DIR/usr/sbin" -type f -executable 2>/dev/null | head -n 1)
fi

# Search in /opt (common for browsers)
if [ -z "$EXEC_PATH" ] && [ -d "$WORK_DIR/opt" ]; then
    EXEC_PATH=$(find "$WORK_DIR/opt" -type f -executable 2>/dev/null | head -n 1)
fi

# Search in /bin
if [ -z "$EXEC_PATH" ] && [ -d "$WORK_DIR/bin" ]; then
    EXEC_PATH=$(find "$WORK_DIR/bin" -type f -executable 2>/dev/null | head -n 1)
fi

if [ -z "$EXEC_PATH" ]; then
    warn "Executable not found automatically"
    EXEC_PATH="$PKG_NAME"
    EXEC_REL_PATH="usr/bin/$PKG_NAME"
else
    EXEC_REL_PATH="${EXEC_PATH#$WORK_DIR/}"
    EXEC_PATH=$(basename "$EXEC_PATH")
    info "Executable found: $EXEC_REL_PATH"
fi

# Look for .desktop file
info "Looking for .desktop file..."
DESKTOP_FILE=""
DESKTOP_ICON_NAME=""

if [ -d "$WORK_DIR/usr/share/applications" ]; then
    DESKTOP_FILE=$(find "$WORK_DIR/usr/share/applications" -name "*.desktop" 2>/dev/null | head -n 1)
fi

# Extract icon name from .desktop if it exists
if [ -n "$DESKTOP_FILE" ] && [ -f "$DESKTOP_FILE" ]; then
    DESKTOP_ICON_NAME=$(grep "^Icon=" "$DESKTOP_FILE" | cut -d'=' -f2 | head -n 1)
    cp "$DESKTOP_FILE" "$WORK_DIR/"
    DESKTOP_FILE="$WORK_DIR/$(basename "$DESKTOP_FILE")"
    info "Found .desktop file with Icon=$DESKTOP_ICON_NAME"
fi

# Create .desktop file if not found
if [ -z "$DESKTOP_FILE" ] || [ ! -f "$DESKTOP_FILE" ]; then
    warn ".desktop file not found, creating default..."
    DESKTOP_ICON_NAME="$PKG_NAME"
    cat > "$WORK_DIR/$PKG_NAME.desktop" << EOF
[Desktop Entry]
Name=$PKG_NAME
Exec=$EXEC_PATH
Icon=$PKG_NAME
Type=Application
Categories=Utility;
EOF
    DESKTOP_FILE="$WORK_DIR/$PKG_NAME.desktop"
fi

# If icon name wasn't extracted, use package name
[ -z "$DESKTOP_ICON_NAME" ] && DESKTOP_ICON_NAME="$PKG_NAME"

# Look for icon
info "Looking for icon..."
ICON_FILE=""

# Search in /usr/share/icons
if [ -d "$WORK_DIR/usr/share/icons" ]; then
    ICON_FILE=$(find "$WORK_DIR/usr/share/icons" -name "${DESKTOP_ICON_NAME}.*" 2>/dev/null | grep -E '\.(png|svg)$' | head -n 1)
fi

# Search in /usr/share/pixmaps
if [ -z "$ICON_FILE" ] && [ -d "$WORK_DIR/usr/share/pixmaps" ]; then
    ICON_FILE=$(find "$WORK_DIR/usr/share/pixmaps" -name "${DESKTOP_ICON_NAME}.*" 2>/dev/null | grep -E '\.(png|svg)$' | head -n 1)
fi

# Search in /opt - PNG first
if [ -z "$ICON_FILE" ] && [ -d "$WORK_DIR/opt" ]; then
    ICON_FILE=$(find "$WORK_DIR/opt" -name "*.png" 2>/dev/null | head -n 1)
fi

# Search in /opt - SVG if no PNG found
if [ -z "$ICON_FILE" ] && [ -d "$WORK_DIR/opt" ]; then
    ICON_FILE=$(find "$WORK_DIR/opt" -name "*.svg" 2>/dev/null | head -n 1)
fi

# Search for any large PNG (probably an icon)
if [ -z "$ICON_FILE" ]; then
    ICON_FILE=$(find "$WORK_DIR" -name "*.png" -size +10k 2>/dev/null | head -n 1)
fi

if [ -z "$ICON_FILE" ] || [ ! -f "$ICON_FILE" ]; then
    warn "Icon not found"
else
    ICON_EXT="${ICON_FILE##*.}"
    # Copy with the name expected by .desktop
    cp "$ICON_FILE" "$WORK_DIR/${DESKTOP_ICON_NAME}.${ICON_EXT}"
    info "Icon copied: ${DESKTOP_ICON_NAME}.${ICON_EXT}"
fi

# Create AppRun script
info "Creating AppRun script..."

cat > "$WORK_DIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${HERE}/usr/sbin:${HERE}/usr/games:${HERE}/bin:${HERE}/sbin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${HERE}/usr/lib/i386-linux-gnu:${HERE}/usr/lib/x86_64-linux-gnu:${HERE}/usr/lib32:${HERE}/usr/lib64:${HERE}/lib:${HERE}/lib/i386-linux-gnu:${HERE}/lib/x86_64-linux-gnu:${HERE}/lib32:${HERE}/lib64:${LD_LIBRARY_PATH}"
export PYTHONPATH="${HERE}/usr/share/pyshared:${PYTHONPATH}"
export XDG_DATA_DIRS="${HERE}/usr/share:${XDG_DATA_DIRS}"
export PERLLIB="${HERE}/usr/share/perl5:${HERE}/usr/lib/perl5:${PERLLIB}"
export GSETTINGS_SCHEMA_DIR="${HERE}/usr/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR}"
export QT_PLUGIN_PATH="${HERE}/usr/lib/qt4/plugins:${HERE}/usr/lib/i386-linux-gnu/qt4/plugins:${HERE}/usr/lib/x86_64-linux-gnu/qt4/plugins:${HERE}/usr/lib32/qt4/plugins:${HERE}/usr/lib64/qt4/plugins:${HERE}/usr/lib/qt5/plugins:${HERE}/usr/lib/i386-linux-gnu/qt5/plugins:${HERE}/usr/lib/x86_64-linux-gnu/qt5/plugins:${HERE}/usr/lib32/qt5/plugins:${HERE}/usr/lib64/qt5/plugins:${QT_PLUGIN_PATH}"

EOF

echo "EXEC_NAME=\"$EXEC_PATH\"" >> "$WORK_DIR/AppRun"
echo "EXEC_REL=\"$EXEC_REL_PATH\"" >> "$WORK_DIR/AppRun"
echo "" >> "$WORK_DIR/AppRun"

cat >> "$WORK_DIR/AppRun" << 'EOF'
# Look for executable
if [ -f "${HERE}/usr/bin/${EXEC_NAME}" ]; then
    EXEC="${HERE}/usr/bin/${EXEC_NAME}"
elif [ -f "${HERE}/${EXEC_REL}" ]; then
    EXEC="${HERE}/${EXEC_REL}"
else
    EXEC=$(find "${HERE}" -type f -name "${EXEC_NAME}" 2>/dev/null | head -n 1)
fi

if [ -z "$EXEC" ]; then
    echo "Error: Executable not found"
    exit 1
fi

exec "$EXEC" "$@"
EOF

chmod +x "$WORK_DIR/AppRun"

# Download appimagetool if not exists
APPIMAGETOOL="appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    info "Downloading appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Remove files from conflicting architectures
info "Cleaning multiple architecture files..."
find "$WORK_DIR" -type f -name "*.so*" 2>/dev/null | while read lib; do
    if file "$lib" 2>/dev/null | grep -q "32-bit" && [[ "$PKG_ARCH" == "x86_64" ]]; then
        rm -f "$lib"
    fi
done

# Create AppImage
OUTPUT_FILE="${PKG_NAME}-${PKG_VERSION}-${PKG_ARCH}.AppImage"
info "Creating AppImage: $OUTPUT_FILE"

# Force correct architecture
case "$PKG_ARCH" in
    x86_64)
        export ARCH=x86_64
        ;;
    i386|i686)
        export ARCH=i686
        ;;
    armv7hl)
        export ARCH=armhf
        ;;
    aarch64)
        export ARCH=aarch64
        ;;
    *)
        export ARCH=$PKG_ARCH
        ;;
esac

info "Using ARCH=$ARCH"
./"$APPIMAGETOOL" "$WORK_DIR" "$OUTPUT_FILE" 2>&1 | grep -v "WARNING" || true

# Clean up
info "Cleaning temporary files..."
rm -rf "$WORK_DIR"

if [ -f "$OUTPUT_FILE" ]; then
    info "AppImage created successfully: $OUTPUT_FILE"
    info "Run with: ./$OUTPUT_FILE"
else
    error "Failed to create AppImage"
fi
