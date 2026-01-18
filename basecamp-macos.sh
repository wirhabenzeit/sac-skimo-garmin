#!/bin/sh
set -e

# 1. Handle ID input
MAP_ID=${1:-1234}

# 2. Disk Image Config
VOL_NAME="GSKI_${MAP_ID}"
DMG_FILE="dist/map_${MAP_ID}.dmg"
IMG_FILE="dist/gmapsuppsac.img"

echo "Preparing BaseCamp loopback for ID: $MAP_ID..."

# Cleanup old files and previous mounts
if [ -d "/Volumes/$VOL_NAME" ]; then
    echo "Unmounting existing volume /Volumes/$VOL_NAME..."
    hdiutil detach "/Volumes/$VOL_NAME" -force || {
        echo "Failed to unmount. trying again..."
        sleep 1
        hdiutil detach "/Volumes/$VOL_NAME" -force
    }
fi

rm -rf "$DMG_FILE" tmp_build

if [ ! -f "$IMG_FILE" ]; then
  echo "Error: $IMG_FILE not found!"
  exit 1
fi

# BaseCamp expects /Garmin/gmapsupp.img at the volume root.
mkdir -p tmp_build/Garmin

ln "$IMG_FILE" tmp_build/Garmin/gmapsupp.img 2>/dev/null || cp "$IMG_FILE" tmp_build/Garmin/gmapsupp.img

echo "Creating disk image..."
hdiutil create "$DMG_FILE" -ov -volname "$VOL_NAME" -fs FAT32 -srcfolder tmp_build/ -quiet

rm -rf tmp_build

echo "Mounting image..."
hdiutil attach -quiet "$DMG_FILE"

cat <<EOF
---------------------------------------------------------
SUCCESS: Map Mounted as /Volumes/$VOL_NAME
---------------------------------------------------------
/Volumes/$VOL_NAME/Garmin/gmapsupp.img

BaseCamp should now see the "Device" automatically.
---------------------------------------------------------
EOF
