#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 Starting Nyarch Assistant${NC}"

# Grant X11 access
xhost +local: 2>/dev/null

# Detect display server
if [ -n "$WAYLAND_DISPLAY" ] && [ -S "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}" ]; then
    echo -e "${GREEN}🌊 Detected Wayland${NC}"
    GDK_BACKEND="wayland,x11"
else
    echo -e "${GREEN}🪟 Detected X11${NC}"
    GDK_BACKEND="x11"
fi

# Create dconf directory on host (fixes permission errors)
mkdir -p ${XDG_RUNTIME_DIR}/dconf

# Get render group ID for GPU access
RENDER_GID=$(getent group render | cut -d: -f3)
VIDEO_GID=$(getent group video | cut -d: -f3)

# Run container
podman run -it --rm \
  --name nyarch-assistant \
  --user $(id -u):$(id -g) \
  --group-add ${RENDER_GID} \
  --group-add ${VIDEO_GID} \
  \
  -e DISPLAY=$DISPLAY \
  -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
  -e XDG_RUNTIME_DIR=/run/user/$(id -u) \
  -e GDK_BACKEND=$GDK_BACKEND \
  -e PULSE_SERVER=unix:/run/user/$(id -u)/pulse/native \
  -e DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus \
  -e SDL_AUDIODRIVER=pulseaudio \
  \
  -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
  -v /run/user/$(id -u):/run/user/$(id -u):rw \
  -v nyarch-data:/home/nyarch/.local/share/nyarchassistant:Z \
  -v nyarch-config:/home/nyarch/.config:Z \
  -v nyarch-cache:/home/nyarch/.cache:Z \
  \
  --device /dev/dri \
  --ipc=host \
  --network host \
  --security-opt label=disable \
  \
  nyarchassistant:latest

# Cleanup
xhost -local: 2>/dev/null
echo -e "${BLUE}👋 Container stopped${NC}"

