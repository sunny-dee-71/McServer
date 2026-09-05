#!/usr/bin/env sh
set -e

FORGE_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${HOME}/.config/mcServer1"
DEPLOYMENT_NAME="Minecraft Forge Server"
DEPLOYMENT_PORT=25565

echo "======================================"
echo "Deploying: $DEPLOYMENT_NAME"
echo "Port: $DEPLOYMENT_PORT"
echo "Directory: $CONFIG_DIR"
echo "======================================"

mkdir -p "$CONFIG_DIR"

if [ -L "$CONFIG_DIR/mods" ]; then
    rm "$CONFIG_DIR/mods"
fi
mkdir -p "$CONFIG_DIR/mods"

echo "Updating server files..."

for item in "$FORGE_DIR"/*; do
    filename=$(basename "$item")

    if [ "$filename" = "run.sh" ] || [ "$filename" = "world" ] || [ "$filename" = "mods" ]; then
        continue
    fi

    target="$CONFIG_DIR/$filename"

    if [ -L "$target" ]; then
        rm "$target"
    fi

    if [ ! -e "$target" ]; then
        ln -s "$item" "$target"
    fi
done

echo "Setting up world directory..."

mkdir -p "$CONFIG_DIR/world"

if mountpoint -q "$FORGE_DIR/world" 2>/dev/null; then
    sudo umount "$FORGE_DIR/world" 2>/dev/null || \
    umount "$FORGE_DIR/world" 2>/dev/null || true
fi

if [ -L "$FORGE_DIR/world" ]; then
    rm "$FORGE_DIR/world"
fi

mkdir -p "$FORGE_DIR/world"

if ! sudo mount --bind "$CONFIG_DIR/world" "$FORGE_DIR/world" 2>/dev/null; then
    if ! mount --bind "$CONFIG_DIR/world" "$FORGE_DIR/world" 2>/dev/null; then
        echo "ERROR: Could not bind mount world directory."
        exit 1
    fi
fi

echo "Preparing mods..."

find "$CONFIG_DIR/mods" -maxdepth 1 -type l -delete
find "$CONFIG_DIR/mods" -maxdepth 1 -name "*.jar" -type f -delete

find "$FORGE_DIR/mods" -type f -name "*.jar" | while read -r jarfile; do
    jarname=$(basename "$jarfile")
    ln -s "$jarfile" "$CONFIG_DIR/mods/$jarname"
done

echo "Starting $DEPLOYMENT_NAME on port $DEPLOYMENT_PORT..."

cd "$CONFIG_DIR"

java @user_jvm_args.txt \
    @libraries/net/minecraftforge/forge/1.20.1-47.4.23/unix_args.txt "$@" &

CHILD_PID=$!

echo "======================================"
echo "Server started with PID: $CHILD_PID"
echo "======================================"

wait "$CHILD_PID"
