#!/bin/bash
# Complete NyarchAssistant AppImage Builder
# Bundles GNOME runtime for XFCE4 compatibility
# Usage: ./build-nyarchassistant-appimage.sh

set -e

echo "🚀 NyarchAssistant AppImage Build Started"
echo "========================================="

# Configuration
BUILDDIR="/tmp/nyarch-build"
APPDIR="/tmp/NyarchAssistant.AppDir"
OUTPUT="$HOME/NyarchAssistant-1.2.0-x86_64.AppImage"
REPO_URL="https://github.com/borrougagnou/NyarchAssistant2Container.git"

# Cleanup
rm -rf "$BUILDDIR" "$APPDIR"
mkdir -p "$BUILDDIR" "$APPDIR"

#######################################
# STEP 1: Install Build Dependencies #
#######################################

echo ""
echo "📦 Step 1/8: Installing build dependencies..."

sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    build-essential meson ninja-build pkg-config git wget gettext \
    python3-dev python3-pip python3-venv python3-gi python3-gi-cairo \
    libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
    libwebkitgtk-6.0-dev libvte-2.91-gtk4-dev libgirepository1.0-dev \
    gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 gir1.2-vte-3.91 gir1.2-webkit2-6.0 \
    libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev \
    libportaudio2 portaudio19-dev libpulse-dev libasound2-dev \
    libjpeg62-turbo-dev libpng-dev zlib1g-dev libfreetype-dev \
    desktop-file-utils libglib2.0-bin fuse libfuse2 \
    libqhull-dev rustc cargo

########################
# STEP 2: Build App    #
########################

echo ""
echo "🏗️  Step 2/8: Building application with Meson..."

cd "$BUILDDIR"
git clone "$REPO_URL"
cd NyarchAssistant2Container

# Build locales
chmod +x build_locale.sh
./build_locale.sh || true

# Configure and build
meson setup _build --prefix=/usr --buildtype=release
meson compile -C _build

# Install to AppDir
DESTDIR="$APPDIR" meson install -C _build

echo "✅ Application built successfully"

################################
# STEP 3: Python Environment   #
################################

echo ""
echo "🐍 Step 3/8: Setting up Python environment..."

python3 -m venv --system-site-packages "$APPDIR/usr/venv"
source "$APPDIR/usr/venv/bin/activate"

pip install --no-cache-dir --upgrade pip setuptools wheel

echo "Installing Python dependencies (this may take 10-15 minutes)..."

pip install --no-cache-dir \
    packaging six python-dateutil requests pillow requests-toolbelt \
    gtts==2.5.4 pyaudio speechrecognition edge-tts \
    voicevox-client==0.4.1 pydub \
    openai==1.84.0 tiktoken gpt4all==2.8.2 ollama \
    llama-index-core==0.12.38 llama-index-readers-file \
    llama-cpp-python faiss-cpu model2vec \
    livepng wordllama==0.3.9 pygame matplotlib scikit-learn \
    newspaper3k lxml lxml-html-clean markdownify \
    duckduckgo-search cssselect curl_cffi \
    expandvars pylatexenc 'mcp[cli]==1.25.0' g4f==0.3.3.4

deactivate

echo "✅ Python environment ready"

#########################
# STEP 4: External Assets#
#########################

echo ""
echo "📥 Step 4/8: Downloading external assets..."

DATADIR="$APPDIR/usr/share/nyarchassistant/data"
mkdir -p "$DATADIR/live2d/web" "$DATADIR/smart-prompts"

cd /tmp

# Live2D Viewer
echo "  - Live2D viewer..."
wget -q -O live2d.tar.xz \
    https://github.com/NyarchLinux/live2d-lipsync-viewer/releases/download/0.5/pack.tar.xz
tar -xJf live2d.tar.xz -C "$DATADIR/live2d/web"

# Arch-chan Avatar
echo "  - Arch-chan avatar..."
wget -q -O arch-chan.png https://nyarchlinux.moe/acchan.png
cp arch-chan.png "$DATADIR/live2d/arch-chan.png"
cp arch-chan.png "$DATADIR/live2d/web/arch-chan.png"

# Smart Prompts Dataset
echo "  - Smart Prompts dataset..."
wget -q -O "$DATADIR/smart-prompts/dataset.csv" \
    https://github.com/NyarchLinux/Smart-Prompts/releases/download/0.3/dataset.csv
wget -q -O "$DATADIR/smart-prompts/NyaMedium_0.3_256.pkl" \
    https://github.com/NyarchLinux/Smart-Prompts/releases/download/0.3/NyaMedium_0.3_256.pkl
wget -q -O "$DATADIR/smart-prompts/l2_supercat_tokenizer_config.json" \
    https://huggingface.co/dleemiller/word-llama-l2-supercat/resolve/main/l2_supercat_tokenizer_config.json

# llama.cpp binaries (for local inference)
echo "  - llama.cpp binaries..."
wget -q -O llamacpp.tar.gz \
    https://github.com/ggml-org/llama.cpp/releases/download/b7662/llama-b7662-bin-ubuntu-x64.tar.gz
tar -xzf llamacpp.tar.gz -C "$APPDIR/usr/bin/" 2>/dev/null || true

echo "✅ Assets downloaded"

#############################
# STEP 5: Bundle GNOME     #
#############################

echo ""
echo "📦 Step 5/8: Bundling GNOME Platform libraries..."
echo "  (Required for XFCE4 compatibility)"

mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/lib/girepository-1.0"

# Copy GTK4 and GNOME libraries
echo "  - GTK4/Libadwaita libraries..."
for lib in libgtk-4 libadwaita-1 libgtksourceview-5 libwebkitgtk-6.0 libvte-2.91-gtk4; do
    find /usr/lib/x86_64-linux-gnu -name "${lib}.so.*" -exec cp -L {} "$APPDIR/usr/lib/" \; 2>/dev/null || true
done

# Copy critical dependencies
echo "  - Core GNOME dependencies..."
for lib in libgraphene libpangocairo libpango libcairo libgdk_pixbuf libgio libgobject libglib; do
    find /usr/lib/x86_64-linux-gnu -name "${lib}*.so.*" -exec cp -L {} "$APPDIR/usr/lib/" \; 2>/dev/null || true
done

# Copy GObject Introspection typelibs (critical for PyGObject)
echo "  - GObject Introspection typelibs..."
for typelib in Gtk-4.0 Adw-1 GtkSource-5 Vte-3.91 WebKit-6.0 GLib-2.0 GObject-2.0 Gio-2.0; do
    find /usr/lib/x86_64-linux-gnu/girepository-1.0 -name "${typelib}.typelib" \
        -exec cp {} "$APPDIR/usr/lib/girepository-1.0/" \; 2>/dev/null || true
done

# Copy GSettings schemas
echo "  - GSettings schemas..."
mkdir -p "$APPDIR/usr/share/glib-2.0/schemas"
cp /usr/share/glib-2.0/schemas/org.gnome*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
cp /usr/share/glib-2.0/schemas/org.gtk*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
cp "$APPDIR/usr/share/glib-2.0/schemas/"*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas/"

# Copy Adwaita icons (essential for GTK4 apps)
echo "  - Adwaita icon theme..."
mkdir -p "$APPDIR/usr/share/icons"
if [ -d "/usr/share/icons/Adwaita" ]; then
    cp -r /usr/share/icons/Adwaita "$APPDIR/usr/share/icons/"
fi

echo "✅ GNOME runtime bundled"

##########################
# STEP 6: Patches        #
##########################

echo ""
echo "🔧 Step 6/8: Applying patches..."

# Patch flatpak-spawn check (critical - app crashes without this)
echo "  - Patching Flatpak detection..."
SYSTEM_PY="$APPDIR/usr/share/nyarchassistant/nyarchassistant/utility/system.py"
if [ -f "$SYSTEM_PY" ]; then
    sed -i '/subprocess.check_output(\["flatpak-spawn"/a\    except FileNotFoundError:\n        return False' "$SYSTEM_PY"
fi

echo "✅ Patches applied"

##########################
# STEP 7: Create AppRun  #
##########################

echo ""
echo "📝 Step 7/8: Creating AppRun script..."

cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
#!/bin/bash
# AppRun script for NyarchAssistant
# Provides isolated environment with GNOME runtime

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

# Python environment
export PYTHONHOME="$HERE/usr/venv"
export PYTHONPATH="$HERE/usr/venv/lib/python3.13/site-packages:$HERE/usr/lib/python3/dist-packages:$PYTHONPATH"
export PATH="$HERE/usr/venv/bin:$HERE/usr/bin:$PATH"
export VIRTUAL_ENV="$HERE/usr/venv"
export PYTHONUSERBASE="$HERE/usr/venv"

# GTK/GNOME environment
export GDK_BACKEND=wayland,x11  # Wayland preferred, X11 fallback
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/share:/usr/local/share}"
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0:${GI_TYPELIB_PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib:${LD_LIBRARY_PATH}"

# GSettings
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas"

# Application data
export NYARCH_DATA_DIR="$HERE/usr/share/nyarchassistant/data"

# Audio
export SDL_AUDIODRIVER=pulseaudio

# Disable Flatpak-specific code
export FLATPAK_DISABLE=1

# Vulkan (for llama-cpp-python GPU acceleration)
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/radeon_icd.json

# Execute application
exec "$HERE/usr/bin/nyarchassistant" "$@"
APPRUN_EOF

chmod +x "$APPDIR/AppRun"

echo "✅ AppRun created"

############################
# STEP 8: Optimization     #
############################

echo ""
echo "⚡ Step 8/8: Optimizing AppImage size..."

# Strip debug symbols
echo "  - Stripping debug symbols..."
find "$APPDIR" -type f -executable -exec strip --strip-debug {} \; 2>/dev/null || true

# Remove Python cache
echo "  - Removing Python cache..."
find "$APPDIR" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$APPDIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$APPDIR" -type f -name "*.pyo" -delete 2>/dev/null || true

# Remove unnecessary files
echo "  - Removing docs and tests..."
rm -rf "$APPDIR/usr/share/doc" "$APPDIR/usr/share/man" 2>/dev/null || true
find "$APPDIR/usr/lib" -type d -name test -exec rm -rf {} + 2>/dev/null || true

echo "✅ Optimization complete"

###############################
# STEP 9: Create AppImage     #
###############################

echo ""
echo "📦 Creating final AppImage..."

cd /tmp

# Download appimagetool
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Extract to avoid FUSE issues
if [ ! -d "appimagetool" ]; then
    ./appimagetool-x86_64.AppImage --appimage-extract >/dev/null 2>&1
    mv squashfs-root appimagetool
fi

# Create AppImage with compression
echo "  - Packaging (this may take several minutes)..."
ARCH=x86_64 ./appimagetool/AppRun "$APPDIR" "$OUTPUT" >/dev/null 2>&1

chmod +x "$OUTPUT"

echo ""
echo "========================================="
echo "✅ BUILD COMPLETE!"
echo "========================================="
echo ""
echo "AppImage location: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | cut -f1)"
echo ""
echo "To test:"
echo "  $OUTPUT"
echo ""
echo "To install system-wide:"
echo "  sudo cp $OUTPUT /opt/"
echo "  sudo chmod +x /opt/$(basename "$OUTPUT")"
echo ""

