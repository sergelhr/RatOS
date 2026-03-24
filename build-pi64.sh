#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/src/config" ]]; then
	rm "$SCRIPT_DIR/src/config"
fi
cat "$SCRIPT_DIR/config/default" >> "$SCRIPT_DIR/src/config"
cat "$SCRIPT_DIR/config/raspberry/default" >> "$SCRIPT_DIR/src/config"
cat "$SCRIPT_DIR/config/raspberry/rpi64" >> "$SCRIPT_DIR/src/config"
source "$SCRIPT_DIR/src/config"

IMGCOUNT=$(ls "$SCRIPT_DIR/src/image/"*raspios-bookworm-arm64*.img.xz 2>/dev/null | wc -l)
if [ $IMGCOUNT -eq 0 ]; then
	echo "Downloading image..."
	find "$SCRIPT_DIR/src/image" -type f -not -name '.gitkeep' -delete
	aria2c -d "$SCRIPT_DIR/src/image" --seed-time=0 $DOWNLOAD_URL_IMAGE
fi

# Check if CustomPiOS is available
if [ ! -d "$SCRIPT_DIR/../CustomPiOS" ]; then
    echo "CustomPiOS not found!"
    echo "Cloning CustomPiOS..."
    cd "$SCRIPT_DIR/.."
    git clone https://github.com/guysoft/CustomPiOS.git
    echo "✓ CustomPiOS cloned"
else
    echo "✓ CustomPiOS found"
fi
echo ""

# Update CustomPiOS paths
echo "Setting up CustomPiOS integration..."
cd "$SCRIPT_DIR/src"
if [ -f "$SCRIPT_DIR/../CustomPiOS/src/update-custompios-paths" ]; then
    "$SCRIPT_DIR/../CustomPiOS/src/update-custompios-paths"
    echo "✓ CustomPiOS paths updated"
else
    echo "ERROR: CustomPiOS update script not found"
    exit 1
fi
echo ""

# Load kernel module
echo "Loading loop kernel module..."
if ! lsmod | grep -q loop; then
    sudo modprobe loop
    echo "✓ Loop module loaded"
else
    echo "✓ Loop module already loaded"
fi
echo ""

# Confirm before building
echo "=========================================="
echo "Ready to build!"
echo "=========================================="
echo ""
echo "This will:"
echo "  1. Create a Raspberry Pi OS Bookworm 64-bit image"
echo "  2. Install Klipper, Moonraker, Mainsail"
echo "  3. Add RatOS configuration"
echo "  4. Add SSH support"
echo "  5. Configure network settings"
echo ""
echo "Target devices: Pi 5, CM5, Pi 4, CM4, Pi 3, Zero 2 W"
echo "Output will be in: $SCRIPT_DIR/src/workspace/"
echo ""
read -p "Continue with build? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled"
    exit 0
fi
echo ""

# Build
echo "Starting build..."
echo "This will take 30-60 minutes depending on your system"
echo ""
cd "$SCRIPT_DIR/src"
sudo bash -x ./build_dist
rm "$SCRIPT_DIR/src/config"

echo ""
echo "=========================================="
echo "Build complete!"
echo "=========================================="
echo ""
echo "Image location: $SCRIPT_DIR/src/workspace/"
echo ""
echo "To flash to SD card:"
echo "  sudo dd if=src/workspace/RatOS-*.img of=/dev/sdX bs=4M status=progress"
echo ""
echo "Or use Balena Etcher / Raspberry Pi Imager"
echo ""
echo "First boot notes for Pi 5 / CM5:"
echo "  - Initial boot may take 2-3 minutes"
echo "  - Wait for Mainsail to be accessible at http://ratos.local"
echo "  - Default credentials: pi / raspberry"
echo ""
