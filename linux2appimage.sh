#!/bin/bash

# Script para converter pacotes .deb para AppImage
# Uso: ./deb2appimage.sh pacote.deb

set -e

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Função para exibir mensagens
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERRO]${NC} $1"
    exit 1
}

warn() {
    echo -e "${YELLOW}[AVISO]${NC} $1"
}

# Verificar se o arquivo .deb foi fornecido
if [ $# -eq 0 ]; then
    error "Uso: $0 <pacote.deb>"
fi

DEB_FILE="$1"

# Verificar se o arquivo existe
if [ ! -f "$DEB_FILE" ]; then
    error "Arquivo não encontrado: $DEB_FILE"
fi

# Verificar dependências
for cmd in dpkg-deb wget; do
    if ! command -v $cmd &> /dev/null; then
        error "Dependência não encontrada: $cmd"
    fi
done

# Obter informações do pacote
info "Extraindo informações do pacote..."
PKG_NAME=$(dpkg-deb -f "$DEB_FILE" Package)
PKG_VERSION=$(dpkg-deb -f "$DEB_FILE" Version)
PKG_ARCH=$(dpkg-deb -f "$DEB_FILE" Architecture)

info "Pacote: $PKG_NAME"
info "Versão: $PKG_VERSION"
info "Arquitetura: $PKG_ARCH"

# Criar diretório de trabalho
WORK_DIR="${PKG_NAME}.AppDir"
info "Criando diretório de trabalho: $WORK_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

# Extrair o conteúdo do .deb
info "Extraindo conteúdo do pacote .deb..."
dpkg-deb -x "$DEB_FILE" "$WORK_DIR"

# Procurar pelo executável principal
info "Procurando executável principal..."
EXEC_PATH=""

# Procurar em /usr/bin
if [ -d "$WORK_DIR/usr/bin" ]; then
    EXEC_PATH=$(find "$WORK_DIR/usr/bin" -type f -executable | head -n 1)
fi

# Procurar em /opt (comum para navegadores como Brave)
if [ -z "$EXEC_PATH" ] && [ -d "$WORK_DIR/opt" ]; then
    EXEC_PATH=$(find "$WORK_DIR/opt" -type f -name "$PKG_NAME" -o -name "${PKG_NAME}-browser" | head -n 1)
fi

if [ -z "$EXEC_PATH" ]; then
    warn "Executável não encontrado automaticamente"
    EXEC_PATH="$PKG_NAME"
else
    # Guardar o caminho relativo a partir de WORK_DIR
    EXEC_REL_PATH="${EXEC_PATH#$WORK_DIR/}"
    EXEC_PATH=$(basename "$EXEC_PATH")
    info "Executável encontrado: $EXEC_REL_PATH"
fi

# Procurar pelo arquivo .desktop
info "Procurando arquivo .desktop..."
DESKTOP_FILE=""
if [ -d "$WORK_DIR/usr/share/applications" ]; then
    DESKTOP_FILE=$(find "$WORK_DIR/usr/share/applications" -name "*.desktop" | head -n 1)
fi

# Criar arquivo .desktop se não existir
if [ -z "$DESKTOP_FILE" ] || [ ! -f "$DESKTOP_FILE" ]; then
    warn "Arquivo .desktop não encontrado, criando um padrão..."
    cat > "$WORK_DIR/$PKG_NAME.desktop" <<EOF
[Desktop Entry]
Name=$PKG_NAME
Exec=$EXEC_PATH
Icon=$PKG_NAME
Type=Application
Categories=Utility;
EOF
    DESKTOP_FILE="$WORK_DIR/$PKG_NAME.desktop"
else
    cp "$DESKTOP_FILE" "$WORK_DIR/"
    DESKTOP_FILE="$WORK_DIR/$(basename $DESKTOP_FILE)"
fi

# Procurar pelo ícone
info "Procurando ícone..."
ICON_FILE=""
ICON_NAME="${PKG_NAME}"

if [ -d "$WORK_DIR/usr/share/icons" ]; then
    ICON_FILE=$(find "$WORK_DIR/usr/share/icons" -name "${PKG_NAME}.*" -o -name "${PKG_NAME}-browser.*" | grep -E '\.(png|svg)

# Criar script AppRun
info "Criando script AppRun..."

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

echo "" >> "$WORK_DIR/AppRun"
echo "# Procurar executável" >> "$WORK_DIR/AppRun"
echo "EXEC_NAME=\"$EXEC_PATH\"" >> "$WORK_DIR/AppRun"
echo "EXEC_REL=\"$EXEC_REL_PATH\"" >> "$WORK_DIR/AppRun"
echo "" >> "$WORK_DIR/AppRun"

cat >> "$WORK_DIR/AppRun" << 'EOF'
if [ -f "${HERE}/usr/bin/${EXEC_NAME}" ]; then
    EXEC="${HERE}/usr/bin/${EXEC_NAME}"
elif [ -f "${HERE}/${EXEC_REL}" ]; then
    EXEC="${HERE}/${EXEC_REL}"
else
    EXEC=$(find "${HERE}" -type f -name "${EXEC_NAME}" | head -n 1)
fi

if [ -z "$EXEC" ]; then
    echo "Erro: Executável não encontrado"
    exit 1
fi

exec "$EXEC" "$@"
EOF

chmod +x "$WORK_DIR/AppRun"

# Baixar appimagetool se não existir
APPIMAGETOOL="appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    info "Baixando appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Remover arquivos de arquiteturas múltiplas que causam conflito
info "Limpando arquivos de múltiplas arquiteturas..."
find "$WORK_DIR" -type f -name "*.so*" | while read lib; do
    # Verificar se é de arquitetura diferente
    if file "$lib" | grep -q "32-bit" && [ "$PKG_ARCH" = "amd64" ]; then
        rm -f "$lib"
    fi
done

# Criar AppImage
OUTPUT_FILE="${PKG_NAME}-${PKG_VERSION}-${PKG_ARCH}.AppImage"
info "Criando AppImage: $OUTPUT_FILE"

# Forçar arquitetura correta
case "$PKG_ARCH" in
    amd64|x86_64)
        export ARCH=x86_64
        ;;
    i386|i686)
        export ARCH=i686
        ;;
    armhf)
        export ARCH=armhf
        ;;
    arm64|aarch64)
        export ARCH=aarch64
        ;;
    *)
        export ARCH=$PKG_ARCH
        ;;
esac

info "Usando ARCH=$ARCH"
./"$APPIMAGETOOL" "$WORK_DIR" "$OUTPUT_FILE" 2>&1 | grep -v "WARNING"

# Limpar
info "Limpando arquivos temporários..."
rm -rf "$WORK_DIR"

info "AppImage criado com sucesso: $OUTPUT_FILE"
info "Execute com: ./$OUTPUT_FILE" | head -n 1)
fi

# Procurar também em /opt
if [ -z "$ICON_FILE" ] && [ -d "$WORK_DIR/opt" ]; then
    ICON_FILE=$(find "$WORK_DIR/opt" -name "*.png" -o -name "*.svg" | head -n 1)
fi

if [ -z "$ICON_FILE" ] || [ ! -f "$ICON_FILE" ]; then
    warn "Ícone não encontrado"
    ICON_NAME="${PKG_NAME}"
else
    ICON_EXT="${ICON_FILE##*.}"
    cp "$ICON_FILE" "$WORK_DIR/${PKG_NAME}.${ICON_EXT}"
    ICON_NAME="${PKG_NAME}"
    info "Ícone copiado: ${PKG_NAME}.${ICON_EXT}"
fi

# Criar script AppRun
info "Criando script AppRun..."
cat > "$WORK_DIR/AppRun" <<'EOF'
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

echo "EXEC=\"\${HERE}/usr/bin/$EXEC_PATH\"" >> "$WORK_DIR/AppRun"
echo 'exec "$EXEC" "$@"' >> "$WORK_DIR/AppRun"

chmod +x "$WORK_DIR/AppRun"

# Baixar appimagetool se não existir
APPIMAGETOOL="appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    info "Baixando appimagetool..."
    wget -q "https://github.com/AppImage/AppImageKit/releases/download/continuous/$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Criar AppImage
OUTPUT_FILE="${PKG_NAME}-${PKG_VERSION}-${PKG_ARCH}.AppImage"
info "Criando AppImage: $OUTPUT_FILE"
ARCH=$PKG_ARCH ./"$APPIMAGETOOL" "$WORK_DIR" "$OUTPUT_FILE"

# Limpar
info "Limpando arquivos temporários..."
rm -rf "$WORK_DIR"

info "AppImage criado com sucesso: $OUTPUT_FILE"
info "Execute com: ./$OUTPUT_FILE"
