#!/bin/bash
set -e

# URLs
MKGMAP_URL="https://www.mkgmap.org.uk/download/mkgmap-r4924.zip"
DATA_URL="https://data.geo.admin.ch/ch.swisstopo-karto.skitouren/skitouren/skitouren_2056.gpkg.zip"

echo "🚀 Setting up Skimo Map Generator..."

if ! command -v curl &> /dev/null; then
    echo "❌ 'curl' is not installed. Please install it first."
    exit 1
fi

if ! command -v unzip &> /dev/null; then
    echo "❌ 'unzip' is not installed. Please install it first."
    exit 1
fi

if ! command -v java &> /dev/null; then
    echo "⚠️  'java' is not installed. You'll need it for ./build.sh."
fi

if ! command -v uv &> /dev/null; then
    echo "⚠️  'uv' is not installed. You'll need it for ./build.sh."
fi

# 1. Download mkgmap
if [ ! -f "mkgmap/mkgmap.jar" ]; then
    echo "⬇️ Downloading mkgmap..."
    curl -L -o mkgmap.zip "$MKGMAP_URL"
    unzip -q mkgmap.zip
    MKGMAP_DIR="$(find . -maxdepth 1 -type d -name 'mkgmap-r*' | head -n 1)"
    if [ -z "$MKGMAP_DIR" ]; then
        echo "❌ Could not find extracted mkgmap directory."
        exit 1
    fi
    rm -rf mkgmap
    mv "$MKGMAP_DIR" mkgmap
    rm mkgmap.zip
    echo "✅ mkgmap installed."
else
    echo "✅ mkgmap already present."
fi

# 2. Download Data
mkdir -p data
if [ ! -f "data/ski_routes_2056.gpkg" ] || [ ! -f "data/ski_network_2056.gpkg" ]; then
    echo "⬇️ Downloading Swisstopo data..."
    curl -L -o data.zip "$DATA_URL"
    echo "📂 Extracting data..."
    unzip -q data.zip -d data/
    rm data.zip
    
    # Flatten structure if nested directories occur
    # Some versions of the zip place files in a subdir. Move them up if so.
    find data -mindepth 2 -name "*.gpkg" -exec mv {} data/ \; 2>/dev/null || true

    # Verify we have the 2 expected files
    if [ -f "data/ski_routes_2056.gpkg" ] && [ -f "data/ski_network_2056.gpkg" ]; then
         echo "✅ Data files ready."
    else
         echo "❌ Expected files 'ski_routes_2056.gpkg' and 'ski_network_2056.gpkg' not found after unzip."
         echo "   Please check the 'data/' directory."
         exit 1
    fi
else
    echo "✅ Data files already present."
fi

echo "🎉 Setup complete! You can now run ./build.sh"
