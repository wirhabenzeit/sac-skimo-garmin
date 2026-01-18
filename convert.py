#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "ogr2osm>=1.2.0",
#   "typer>=0.12.3",
# ]
# ///
from __future__ import annotations

import logging
from pathlib import Path

import ogr2osm
import ogr2osm.ogr_datasource as ogr_datasource
import typer


ROOT = Path(__file__).resolve().parent


class SACTranslation(ogr2osm.TranslationBase):
    def __init__(self):
        super().__init__()
        self.ways = None
        self.relations = None

    def filter_layer(self, layer):
        return layer

    def filter_feature(self, ogrfeature, layer_fields, reproject):
        return ogrfeature

    def filter_tags(self, tags):
        osm_tags = {
            "type": "route",
            "route": "piste",
        }

        # Determine discipline/piste:type
        disc = tags.get("discipline")
        if disc == "ski_tour":
            osm_tags["piste:type"] = "skitour"
        elif disc == "snowshoe_tour" or disc == "ski_snowshoe_tour":
            osm_tags["piste:type"] = "snowshoe"
        else:
            osm_tags["piste:type"] = "skitour"

        # Access (from ski_network)
        # 0: Standard -> sac:access=standard
        # 1: Foot only -> sac:access=foot
        # 2: Caution -> sac:access=caution
        if "access" in tags:
            try:
                acc = int(tags["access"])
            except (TypeError, ValueError):
                acc = None
            if acc == 0:
                osm_tags["sac:access"] = "standard"
            elif acc == 1:
                osm_tags["sac:access"] = "foot"
            elif acc == 2:
                osm_tags["sac:access"] = "caution"

        # Ensure generic names for network segments to avoid 'Unknown'
        if "name" not in osm_tags and "segm_id" in tags:
            osm_tags["name"] = "Ski Info"

        # Direction (from ski_network)
        # 0: Both, 1: Up, 2: Down, 10: Up start, 20: Down start
        if "direction" in tags:
            osm_tags["sac:direction"] = tags["direction"]

        # Difficulty
        if diff := tags.get("difficulty_en"):
            osm_tags["piste:difficulty"] = diff

        # Name
        if tags.get("name_en") and tags.get("target_name"):
            osm_tags["name"] = f"{tags.get('target_name')} ({tags.get('name_en')})"
        elif tags.get("target_name"):
            osm_tags["name"] = tags.get("target_name")
        elif tags.get("name"):
            osm_tags["name"] = tags.get("name")

        # Website
        if tags.get("url_sac_en"):
            osm_tags["website"] = tags.get("url_sac_en")

        # Description construction
        description_parts = []
        if tags.get("target_altitude"):
            description_parts.append(f"Altitude: {tags.get('target_altitude')}m.")
        if tags.get("difficulty_en"):
            description_parts.append(f"Difficulty: {tags.get('difficulty_en')}.")
        if tags.get("ascent_altitude") and tags.get("descent_altitude"):
            description_parts.append(
                f"Elevation gain: +{tags.get('ascent_altitude')}m -{tags.get('descent_altitude')}m."
            )
        if tags.get("ascent_time"):
            val = tags.get("ascent_time_label") or tags.get("ascent_time")
            if val:
                description_parts.append(f"Ascent times: {val}.")
        if tags.get("source_txt"):
            description_parts.append(f"Source: {tags.get('source_txt')}.")

        if description_parts:
            osm_tags["description"] = " ".join(description_parts)

        return osm_tags

    def merge_tags(self, geometry_type, tags_existing_geometry, tags_new_geometry):
        return {**tags_existing_geometry, **tags_new_geometry}


def run_ogr2osm(input_path: Path, output_path: Path) -> None:
    ogr2osmlogger = logging.getLogger("ogr2osm")
    ogr2osmlogger.setLevel(logging.ERROR)
    ogr2osmlogger.addHandler(logging.StreamHandler())

    orig_get_driver = ogr_datasource.ogr.GetDriverByName

    def get_driver(name: str):
        if name == "Memory":
            mem_driver = orig_get_driver("MEM")
            if mem_driver is not None:
                return mem_driver
        return orig_get_driver(name)

    ogr_datasource.ogr.GetDriverByName = get_driver

    translation = SACTranslation()
    datasource = ogr2osm.OgrDatasource(translation)
    datasource.open_datasource(str(input_path))

    osmdata = ogr2osm.OsmData(translation)
    osmdata.process(datasource)

    datawriter = ogr2osm.OsmDataWriter(str(output_path))
    osmdata.output(datawriter)


def convert(
    input_path: Path = typer.Option(
        ..., "-i", "--input", exists=True, help="Input GPKG file."
    ),
    output_path: Path = typer.Option(
        ..., "-o", "--output", help="Output OSM file."
    ),
) -> None:
    input_path = (ROOT / input_path) if not input_path.is_absolute() else input_path
    output_path = (ROOT / output_path) if not output_path.is_absolute() else output_path
    output_path.parent.mkdir(parents=True, exist_ok=True)

    if not input_path.exists():
        raise typer.BadParameter(f"Missing {input_path}. Run ./setup.sh first.")

    print(f"▶ Converting {input_path} -> {output_path}...")
    run_ogr2osm(input_path, output_path)


if __name__ == "__main__":
    typer.run(convert)
