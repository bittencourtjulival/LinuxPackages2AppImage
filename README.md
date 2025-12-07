# 📦 Linux2AppImage Converter

Bash script to convert Linux packages into portable AppImage format.

## 🎯 What it does

Converts Linux packages into AppImage format, allowing you to run applications on any Linux distribution without installation.

## 📋 Requirements

### Debian/Ubuntu
```bash
sudo apt install dpkg-deb wget
```

### Arch Linux
```bash
sudo pacman -S dpkg wget
```

### Fedora
```bash
sudo dnf install dpkg wget
```

## 🚀 Installation

1. Download the script:
```bash
wget https://your-repository.com/linux2appimage.sh
```

2. Make it executable:
```bash
chmod +x linux2appimage.sh
```

## 💻 Usage

### Basic syntax

```bash
./linux2appimage.sh <package linux>
```

### Example

```bash
./linux2appimage.sh brave-browser_1.85.113_amd64.deb
```

### What happens

1. Extracts the package contents
2. Automatically detects executable, icon and .desktop file
3. Creates the necessary AppDir structure
4. Downloads appimagetool (first time only)
5. Generates the `.AppImage` file

## 📂 Output

The script creates a file in the format:

```
package-name-version-architecture.AppImage
```

Example: `brave-browser-1.85.113-amd64.AppImage`

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

The script searches in `/usr/bin` and `/opt`. If it fails, check manually:

```bash
dpkg-deb -c package.deb | grep bin
```

### Multiple architecture error

The script automatically removes libraries from conflicting architectures. If it persists, verify the package is compatible with your architecture.

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

## 📝 Notes

- The created AppImage is portable but may require basic system libraries
- Packages with many dependencies might not work perfectly
- Test the AppImage before distributing

## 🤝 Limitations

- Does not automatically include dependencies (only package contents)
- Complex applications may need manual adjustments
- Best for self-contained applications

## 🚀 Future Plans

Support for additional package formats:
- RPM packages
- Snap packages
- Flatpak packages
- tar.gz archives

## 📄 License

Free to use and modify.

---

**Developed to simplify AppImage creation from Linux packages**
