# GTA Map for CarPlay

A live, GTA-radar-style navigation map for Apple CarPlay. It uses only free services:

| Piece | Service | Cost / key |
|---|---|---|
| Map tiles + fonts | [OpenFreeMap](https://openfreemap.org) (OpenStreetMap data) | free, no API key |
| Map renderer | [MapLibre Native](https://github.com/maplibre/maplibre-native) (iOS) / MapLibre GL JS (web preview) | open source |
| Search & routing | Apple MapKit (`MKLocalSearchCompleter`, `MKDirections`) | free, built into iOS |
| District / street banner | `CLGeocoder` | free, built into iOS |

## What you get

- **Dark, high-contrast base map** (`style/gta-style.json`): near-black land, navy water, grey roads with dark casings, low 3D buildings, uppercase labels.
- **Glowing waypoint route**: a three-layer purple neon line (wide blurred glow, inner glow, bright core). New routes "paint" across the map, then the glow pulses.
- **Player blip**: a white GTA-style arrow that rotates with your heading.
- **Chase camera**: tilted 50°, heading-up, with the player in the lower third. Panning or zooming stops the chase; the recenter button brings it back.
- **Location banner**: street name and district in the corner, updated as you drive.
- **CarPlay**: search template, trip preview with ETA, turn-by-turn maneuver cards, zoom, recenter and pan buttons.
- **Phone UI**: the same map with a "Set waypoint…" search. A route set on the phone also appears on the car screen.

## Run it in the CarPlay Simulator

1. `brew install xcodegen`, then run `xcodegen` in the repo root to generate `GTAMap.xcodeproj`. Swift Package Manager pulls in MapLibre.
2. Open the project, set your development team, and run on an iPhone simulator.
3. In the Simulator, choose **I/O ▸ External Displays ▸ CarPlay**.
4. Simulate driving with **Features ▸ Location ▸ City Run / Freeway Drive**.

### On a real car

CarPlay navigation apps need the `com.apple.developer.carplay-maps` entitlement, which Apple must grant to your team. Request it at <https://developer.apple.com/carplay/>. Until then the entitlement (`Config/GTAMap.entitlements`) is applied to Simulator builds only, so a free team can still sign; once granted, enable it for device builds in `project.yml`.

## Tune the look in a browser

`web/index.html` renders the same style file with a simulated drive:

```sh
python3 -m http.server 8000   # from the repo root
open http://localhost:8000/web/
```

Click anywhere to set a waypoint. The route comes from the public OSRM demo server and is for previews only. Change colours in `style/gta-style.json`, reload, and rebuild the app.

Some colours to try:
- **Yellow mission route**: set `route-glow-*` to `#f0c330` and `route-core` to `#fff4c2`.
- **Blue neon**: set `route-glow-*` to `#2f8cff` and `route-core` to `#d6ecff`.

## Layout

```
style/gta-style.json            shared MapLibre style (validated against the style spec)
GTAMap/Core/NavigationModel     location, heading, route, progress, geocoded area name
GTAMap/Map/MapViewController    MapLibre view, chase camera, route paint + glow pulse
GTAMap/Map/PlayerBlip           arrow image
GTAMap/Map/LocationHUDView      GTA-style street/district text
GTAMap/CarPlay/                 CarPlay scene delegate + search
GTAMap/Phone/                   phone UI
web/index.html                  browser preview
```

Map data © OpenStreetMap contributors, served by OpenFreeMap. Keep the attribution button visible.
