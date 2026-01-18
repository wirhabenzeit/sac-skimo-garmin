# Skimo Map Generator (Swiss Alpine Club)

This tool generates a **transparent, custom-styled ski touring map** for Garmin devices (and BaseCamp) using official data from the Swiss Alpine Club (SAC).

The map highlights ski routes, foot access, and caution sections with distinct visual styles, designed to be overlaid on top of a topographic base map (like Swisstopo or OSM).

## 🚀 Quick Start

### 1. Prerequisites

- **Java** (Runtime Environment): Required to run `mkgmap`.
- **uv** (Python Package Manager): Used for inline script dependencies. [Install uv](https://github.com/astral-sh/uv).

### 2. Setup

Run the setup script to download the necessary tools (`mkgmap`) and the latest SAC data (Swisstopo):

```bash
./setup.sh
```

_This will download ~25MB of data to `data/` and the mkgmap tool to `mkgmap/`._

### 3. Build the Map

Generate the Garmin map file (`dist/gmapsuppsac.img`):

```bash
./build.sh
```

This runs `uv run convert.py` twice, which contains inline dependencies (PEP 723).

Optional BaseCamp mount (macOS):

```bash
./build.sh --basecamp
# or provide an ID used for the DMG/volume name:
./build.sh --basecamp 1234
```

Keep intermediate OSM files:

```bash
./build.sh --keep-osm
```

### 4. Install in BaseCamp (macOS, optional -- just for testing)

Mount the generated map as a virtual device for BaseCamp. You can provide an arbitrary ID to manage cache/versions.

```bash
./basecamp-macos.sh 1234
```

open BaseCamp, and you should see the "SkimoSAC" device.

---

## 🎨 Visual Legend

The map uses a custom **TYP** file to override specific Garmin line types. Since clarity is key, we use high-contrast patterns:

| Route Type              | Visual Style | Color      | Pattern             |
| :---------------------- | :----------- | :--------- | :------------------ |
| **Standard Ski Tour**   | Solid Line   | **Blue**   | 🔵 Continuous       |
| **Foot / Carrying**     | Dotted Line  | **Blue**   | 🔵🔵⚪⚪⚪ (Dots)   |
| **Caution / Difficult** | Dashed Line  | **Blue**   | 🔵🔵🔵⚪⚪ (Dashes) |
| **Snowshoe Trail**      | Solid Line   | **Purple** | 🟣 Continuous       |

_Note: The map is **Non-Routable**. It is purely a visual overlay._

---

## 📂 Project Structure

- **`data/`**: Input GeoPackage files (downloaded by setup).
- **`dist/`**: Release-ready map files (`gmapsuppsac.img`).
- **`ski.txt`**: The **TYP file** defining the colors and patterns. Edit this to change the look.
- **`convert.py`**: Python logic for GPKG translation (inline deps) and ogr2osm conversion.
- **`build.sh`**: The main orchestration script.

---

## 🧠 Technical Details

### Data Sources

The map is built from the **Swiss Alpine Club (SAC) Ski Tours** dataset provided by Swisstopo.

- **Source**: https://data.geo.admin.ch/browser/index.html#/collections/ch.swisstopo-karto.skitouren
- **Original Format**: GeoPackage (`.gpkg`).
- **Layers**: The tool expects two files: `ski_routes_2056.gpkg` (Rich metadata) and `ski_network_2056.gpkg` (Connectivity graph).

### Attribute Mapping (`convert.py`)

GPKG attributes are translated to OSM tags for `mkgmap` processing:

| Dataset     | Attribute    | Value          | OSM Tag               | Visual Result      |
| :---------- | :----------- | :------------- | :-------------------- | :----------------- |
| **Routes**  | `route_name` | _Any_          | `name`                | (Route Name Label) |
| **Network** | `access`     | `0` (Standard) | `sac:access=standard` | **Solid Blue**     |
|             |              | `1` (Foot)     | `sac:access=foot`     | **Dotted Blue**    |
|             |              | `2` (Caution)  | `sac:access=caution`  | **Dashed Blue**    |
|             | `discipline` | `snowshoe..`   | `piste:type=snowshoe` | **Purple**         |

_Note: The metadata from `ski_routes` (e.g., names) is NOT currently merged onto the `ski_network` segments._

### Pipeline Steps

1.  **Translation**: Convert each GPKG file into an intermediate `.osm` XML file using `ogr2osm`.
    - Manual use:
      ```bash
      uv run convert.py -i data/ski_routes_2056.gpkg -o output/ski_routes.osm
      uv run convert.py -i data/ski_network_2056.gpkg -o output/ski_network.osm
      ```
2.  **Compilation**: `mkgmap` reads both OSM files, applies the style rules (`ski-style/`), and compiles them into a **single** Garmin Image file (`dist/gmapsuppsac.img`) with the custom visual definitions from `ski.txt`.

## Disclaimer

The SAC ski routes cover Switzerland and nearby border areas. The dataset is produced by the Swiss Alpine Club, checked by cantonal hunting authorities for wildlife compatibility, and updated annually, but actual routes depend on current conditions. SAC and Swisstopo accept no liability for accuracy or accidents; detailed tour planning is recommended. More info: https://www.sac-cas.ch/en/.

## License

Code: Open Source.
Data: Copyright Swiss Alpine Club (SAC) / Swisstopo. Please respect their terms of use.

---

## Releasing

Build locally and attach the artifact to a GitHub release.

```bash
./build.sh
git tag -a v0.1.0 -m "SkimoSAC v0.1.0"
git push origin v0.1.0
gh release create v0.1.0 dist/gmapsuppsac.img \
  --title "SkimoSAC v0.1.0" \
  --notes "Release notes here."
```
