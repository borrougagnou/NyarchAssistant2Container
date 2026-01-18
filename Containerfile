# Stage 1: Build Stage
FROM debian:trixie-slim AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential meson ninja-build pkg-config git wget gettext \
    # Python (use venv to avoid externally-managed-environment)
    python3-dev python3-pip python3-venv \
    python3-gi python3-gi-cairo \
    # GTK4/GNOME development - ALL VERIFIED
    libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
    libwebkitgtk-6.0-dev libvte-2.91-gtk4-dev libgirepository1.0-dev \
    gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 gir1.2-vte-3.91 \
    # SDL2 for pygame
    libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev \
    # Audio libraries
    libportaudio2 portaudio19-dev libpulse-dev libasound2-dev \
    # Image processing
    libjpeg62-turbo-dev libpng-dev zlib1g-dev libfreetype-dev \
    # Additional
    libqhull-dev rustc cargo desktop-file-utils libglib2.0-bin \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
COPY . .

# Create virtual environment with system site packages
ENV VIRTUAL_ENV=/opt/venv
RUN python3 -m venv --system-site-packages $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

# Install ALL Python dependencies in virtual environment
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir \
    packaging six python-dateutil \
    requests pillow requests-toolbelt gtts==2.5.4 expandvars \
    pyaudio speechrecognition openai==1.84.0 voicevox-client==0.4.1 \
    livepng wordllama==0.3.9 edge-tts scikit-learn pygame \
    tiktoken newspaper3k lxml lxml-html-clean pylatexenc \
    matplotlib gpt4all==2.8.2 ollama llama-index-core==0.12.38 \
    llama-index-readers-file 'mcp[cli]==1.25.0' g4f==0.3.3.4 \
    curl_cffi markdownify

# Build application
RUN chmod +x build_locale.sh && ./build_locale.sh || true && \
    meson setup _build --prefix=/usr --buildtype=release && \
    meson compile -C _build && \
    DESTDIR=/install meson install -C _build

# Download Live2D assets
RUN mkdir -p /install/usr/share/nyarchassistant/data/live2d/web && \
    cd /tmp && \
    wget -q -O download.tar.xz https://github.com/NyarchLinux/live2d-lipsync-viewer/releases/download/0.5/pack.tar.xz && \
    wget -q -O arch-chan.png https://nyarchlinux.moe/acchan.png && \
    tar -xJf download.tar.xz -C /install/usr/share/nyarchassistant/data/live2d/web && \
    cp arch-chan.png /install/usr/share/nyarchassistant/data/live2d/arch-chan.png && \
    mv arch-chan.png /install/usr/share/nyarchassistant/data/live2d/web/arch-chan.png

# Download smart-prompts assets
RUN mkdir -p /install/usr/share/nyarchassistant/data/smart-prompts && \
    cd /tmp && \
    wget -q https://github.com/NyarchLinux/Smart-Prompts/releases/download/0.3/dataset.csv && \
    wget -q https://github.com/NyarchLinux/Smart-Prompts/releases/download/0.3/NyaMedium_0.3_256.pkl && \
    wget -q https://huggingface.co/dleemiller/word-llama-l2-supercat/resolve/main/l2_supercat_tokenizer_config.json && \
    mv dataset.csv                        /install/usr/share/nyarchassistant/data/smart-prompts/. && \
    mv NyaMedium_0.3_256.pkl              /install/usr/share/nyarchassistant/data/smart-prompts/. && \
    mv l2_supercat_tokenizer_config.json  /install/usr/share/nyarchassistant/data/smart-prompts/.



######################
# this repo is awful #
#####################





# Stage 2: Minimal Runtime Stage
FROM debian:trixie-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Python runtime
    python3 python3-gi python3-gi-cairo python3-venv \
    python3-packaging python3-six \
    # GTK4/GNOME runtime
    libgtk-4-1 libadwaita-1-0 libgtksourceview-5-0 \
    libwebkitgtk-6.0-4 libvte-2.91-gtk4-0 libgirepository-1.0-1 \
    gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 \
    gir1.2-vte-3.91 gir1.2-webkit-6.0 \
    # SDL2 runtime
    libsdl2-2.0-0 libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-ttf-2.0-0 \
    # Audio runtime
    libportaudio2 pulseaudio-utils libasound2 \
    # Image libraries
    libjpeg62-turbo libpng16-16 libfreetype6 \
    # Utilities
    dconf-gsettings-backend gsettings-desktop-schemas adwaita-icon-theme \
    git ffmpeg libglib2.0-bin desktop-file-utils \
    dbus \
    && rm -rf /var/lib/apt/lists/*

# Copy application files from builder
COPY --from=builder /install /
# Copy ENTIRE virtual environment
COPY --from=builder /opt/venv /opt/venv

# Patch system.py to handle missing flatpak-spawn
RUN sed -i '/subprocess.check_output(\["flatpak-spawn"/a\    except FileNotFoundError:\n        return False' \
    /usr/share/nyarchassistant/nyarchassistant/utility/system.py

# Create non-root user and fix permissions
RUN useradd -m -s /bin/bash nyarch && \
    chown -R nyarch:nyarch /usr/share/nyarchassistant && \
    chown -R nyarch:nyarch /opt/venv && \
    chmod -R 755 /usr/share/nyarchassistant && \
    chmod +x /usr/bin/nyarchassistant && \
    glib-compile-schemas /usr/share/glib-2.0/schemas/ || true && \
    update-desktop-database /usr/share/applications || true && \
    ln -s /usr/share/nyarchassistant /app && echo "DONE"

# Environment setup
ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONPATH="/usr/share/nyarchassistant:/opt/venv/lib/python3.13/site-packages:/usr/lib/python3/dist-packages" \
    PYTHONUSERBASE="/opt/venv" \
    GI_TYPELIB_PATH="/usr/lib/x86_64-linux-gnu/girepository-1.0" \
    XDG_DATA_DIRS="/usr/share" \
    SDL_AUDIODRIVER=pulseaudio

USER nyarch
WORKDIR /home/nyarch

CMD ["nyarchassistant"]

