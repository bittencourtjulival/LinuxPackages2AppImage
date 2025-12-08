# 📦 Linux2AppImage Converter

Bash scripts to convert Linux packages into portable AppImage format.

## 🎯 What it does

Converts Linux packages (.deb and .rpm) into AppImage format, allowing you to run applications on any Linux distribution without installation.

## 📋 Requirements

### Debian/Ubuntu
```bash
# For DEB support
sudo apt install dpkg-deb wget

# For RPM support
sudo apt install rpm2cpio cpio wget
```

### Arch Linux
```bash
# For DEB support
sudo pacman -S dpkg wget

# For RPM support
sudo pacman -S rpmextract cpio wget
```

### Fedora
```bash
# For DEB support
sudo dnf install dpkg wget

# For RPM support (already included)
sudo dnf install rpm cpio wget
```

## 🚀 Installation

1. Clone or download the scripts:
```bash
git clone https://github.com/your-repo/linux2appimage.git
cd linux2appimage
```

2. Make scripts executable:
```bash
chmod +x linux2appimage.sh deb2appimage.sh rpm2appimage.sh
```

## 💻 Usage

### Universal Wrapper (Recommended)

The wrapper automatically detects the package type and calls the appropriate converter:

```bash
./linux2appimage.sh <package.deb|package.rpm>
```

**Examples:**
```bash
./linux2appimage.sh firefox_130.0-1_amd64.deb
./linux2appimage.sh chromium-130.0-1.x86_64.rpm
```

### Direct Converters

You can also use the format-specific converters directly:

```bash
# For DEB packages
./deb2appimage.sh package.deb

# For RPM packages
./rpm2appimage.sh package.rpm
```

## 📁 Project Structure

```
linux2appimage/
├── linux2appimage.sh     # Universal wrapper (auto-detects format)
├── deb2appimage.sh       # DEB to AppImage converter
└── rpm2appimage.sh       # RPM to AppImage converter
```

## 🔄 Conversion Process

1. Extracts package contents
2. Detects executable, icon and .desktop file automatically
3. Creates the necessary AppDir structure
4. Downloads appimagetool (first time only)
5. Generates the `.AppImage` file

## 📂 Output

The scripts create files in the format:

```
package-name-version-architecture.AppImage
```

**Examples:**
- `brave-browser-1.85.113-amd64.AppImage`
- `firefox-130.0-1-x86_64.AppImage`

## ▶️ Running the AppImage

### Normal execution

```bash
./application-name.AppImage
```

### Without terminal warnings

```bash
./application-name.AppImage 2>/dev/null
```

### With special flags (browsers)

```bash
./browser.AppImage --disable-gpu --disable-software-rasterizer
```

## ⚙️ FUSE Installation

AppImage requires FUSE to run. Install it if needed:

### Debian/Ubuntu
```bash
sudo apt install fuse libfuse2
```

### Arch Linux
```bash
sudo pacman -S fuse2
```

### Fedora
```bash
sudo dnf install fuse fuse-libs
```

## ⚠️ Common Warnings

### VAAPI/GLib Errors

Errors like `vaInitialize failed` or `GLib-GObject` are non-critical warnings. The application usually works normally.

**Solution**: Run with `2>/dev/null` to hide warnings.

### Missing Libraries

If the AppImage doesn't run, you might be missing system dependencies. Install required libraries:

**Debian/Ubuntu:**
```bash
sudo apt install libgtk-3-0 libglib2.0-0
```

**Arch Linux:**
```bash
sudo pacman -S gtk3 glib2
```

**Fedora:**
```bash
sudo dnf install gtk3 glib2
```

## 🔧 Troubleshooting

### Executable not found

The scripts search in `/usr/bin`, `/usr/sbin`, `/opt`, and `/bin`. If it fails, check manually:

**For DEB:**
```bash
dpkg-deb -c package.deb | grep bin
```

**For RPM:**
```bash
rpm -qpl package.rpm | grep bin
```

### Multiple architecture error

The scripts automatically remove libraries from conflicting architectures. If it persists, verify the package is compatible with your architecture.

### AppImage won't execute

1. Check permissions:
```bash
chmod +x file.AppImage
```

2. Verify FUSE is installed (see FUSE Installation section above)

3. Try running with verbose output:
```bash
./file.AppImage --appimage-extract-and-run
```

### Converter script not found

Make sure all three scripts are in the same directory:
```bash
ls -l linux2appimage.sh deb2appimage.sh rpm2appimage.sh
```

## 📝 Notes

- The created AppImage is portable but may require basic system libraries
- Packages with many dependencies might not work perfectly
- Test the AppImage before distributing
- Each format has its own specialized converter for better compatibility

## 🎨 Supported Formats

### ✅ Currently Supported
- **DEB** - Debian, Ubuntu, Linux Mint, Pop!_OS, etc.
- **RPM** - Fedora, RHEL, CentOS, openSUSE, etc.

### 🚀 Future Plans

Support for additional package formats:
- Snap packages
- Flatpak packages
- tar.gz archives
- pacman packages

## 🤝 Advantages

- **Universal wrapper** - one command for any package type
- **Automatic detection** - no need to specify format
- **Modular design** - easy to add new formats
- **Cross-distribution** - works on Debian, Arch, Fedora, etc.

## 📄 License

Free to use and modify.

---

**Developed to simplify AppImage creation from Linux packages**
