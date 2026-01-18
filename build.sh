#!/bin/bash
set -e

if ! command -v uv &> /dev/null; then
    echo "❌ 'uv' is not installed. Please install it first: https://github.com/astral-sh/uv"
    exit 1
fi

# Options
BASECAMP=0
BASECAMP_ID="1234"
KEEP_OSM=0
while [ $# -gt 0 ]; do
    case "$1" in
        --basecamp)
            BASECAMP=1
            shift
            if [ $# -gt 0 ] && [[ "$1" != --* ]]; then
                BASECAMP_ID="$1"
                shift
            fi
            ;;
        --basecamp=*)
            BASECAMP=1
            BASECAMP_ID="${1#*=}"
            shift
            ;;
        --keep-osm)
            KEEP_OSM=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Configuration
INPUT_GPKG="data/ski_routes_2056.gpkg"
INPUT_NETWORK="data/ski_network_2056.gpkg"
OSM_FILE="output_tmp/ski_routes.osm"
NETWORK_OSM="output_tmp/ski_network.osm"
IMG_FILE="dist/gmapsuppsac.img"
TMP_OUTPUT="output_tmp"
MAP_ID="63240901"
MAP_DESC="SAC Skimo Routes"

uv run convert.py -i "$INPUT_GPKG" -o "$OSM_FILE"
uv run convert.py -i "$INPUT_NETWORK" -o "$NETWORK_OSM"

if [ ! -f "mkgmap/mkgmap.jar" ]; then
    echo "❌ mkgmap not found. Run ./setup.sh first."
    exit 1
fi

# 3. Convert OSM to Garmin IMG
echo "▶ Creating Garmin IMG $IMG_FILE..."
java -Xmx2G -jar mkgmap/mkgmap.jar \
    --mapname="$MAP_ID" \
    --description="$MAP_DESC" \
    --gmapsupp \
    --transparent \
    --style-file=ski-style \
    --remove-short-arcs \
    --add-pois-to-areas \
    --family-id=901 \
    --family-name="SkimoSAC" \
    --series-name="SkimoSAC" \
    --output-dir="$TMP_OUTPUT" \
    "$NETWORK_OSM" "ski.txt"

mkdir -p dist
if [ ! -f "$TMP_OUTPUT/gmapsupp.img" ]; then
    echo "❌ Expected $TMP_OUTPUT/gmapsupp.img not found."
    exit 1
fi
mv -f "$TMP_OUTPUT/gmapsupp.img" "$IMG_FILE"
if [ "$KEEP_OSM" -eq 1 ]; then
    cp -f "$OSM_FILE" "$NETWORK_OSM" dist/
fi
rm -rf "$TMP_OUTPUT"

echo "✔ Done! Created $IMG_FILE"

if [ "$BASECAMP" -eq 1 ]; then
    ./basecamp-macos.sh "$BASECAMP_ID"
fi
