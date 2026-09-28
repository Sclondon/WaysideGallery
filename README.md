# Wayside Gallery

A virtual gallery you can walk through. Rooms open onto each other along one corridor
and the artwork hangs on the walls under picture lights. Aim at a piece to see its
title, then step up to it to read the wall text and browse from piece to piece.

Godot **4.7**, Compatibility renderer, so the editor looks like the web build. Open
`project.godot` and press F5.

## Controls

| | Keyboard / mouse | Gamepad | Touch |
|---|---|---|---|
| Walk | WASD, ↑/↓ | left stick | drag on the left side |
| Look | mouse (click to capture), ←/→ turn | right stick | drag on the right side |
| Stroll faster | Shift | L3 | |
| Look closer | E / Enter / Space / click | A | tap the picture |
| Previous / next piece | ← → or A D, Q | d-pad, LB / RB | swipe, or the buttons |
| Back to walking | E / Esc / Backspace | B | Back button |

## Hanging your own art

1. Drop images (`png`, `jpg`, `webp`...) into `art/`. Every image there gets hung.
2. Delete the `placeholder_*.png` files and their entries in `art/catalog.json`.
3. Describe your pieces in `art/catalog.json` (all fields are optional):

```json
{
  "artist": "Your Name",
  "pieces": [
    {
      "file": "harbour.jpg",
      "title": "Harbour at Dusk",
      "year": 2024,
      "medium": "Oil on canvas",
      "description": "Wall text shown when you look closer.",
      "width_cm": 90,
      "frame": "walnut"
    }
  ]
}
```

- **Order**: pieces are hung in catalog order, then any images not in the catalog in
  file-name order. The **last** piece gets the end wall of the last room to itself, so
  put your showpiece last.
- **Size**: give `width_cm` and/or `height_cm` to hang a piece at its real size.
  Otherwise its longest side is 1.3 m. Anything too big for its wall is scaled down.
- **Frame**: `black`, `walnut`, `oak`, `gold`, `white` or `none` (a plain canvas edge).
  If you leave it out, one is picked from the file name.
- The top-level `artist` applies to every piece unless a piece sets its own.
- Rooms get added automatically: 5 pieces fit in one room, then 6 more per extra room.

Images are imported uncompressed with mipmaps, capped at 2048 px (`[importer_defaults]` in
`project.godot`). Larger files are scaled down on import, so there's no need to resize them first.

## Project layout

| Path | What |
|---|---|
| `scripts/main.gd` | game flow: welcome card, walking, viewing a piece, touch input, autotest |
| `scripts/gallery.gd` | builds the rooms, doors, benches, lights, frames and plaques, and hangs the art |
| `scripts/art_catalog.gd` | finds images in `art/` and reads `catalog.json` |
| `scripts/player.gd` | first-person walker |
| `scripts/hud.gd` | on-screen UI: prompt, wall-text card, touch joystick, fades |
| `shaders/floor.gdshader` | procedural oak plank floor |
| `scripts/tools/bake_placeholders.gd` | paints the placeholder pictures |
| `fonts/` | Cormorant Garamond and Jost (SIL OFL, licences alongside) |

Regenerate the placeholders with
`godot --headless --path . -s scripts/tools/bake_placeholders.gd` (this overwrites `art/catalog.json`).

## Web build

Published with GitHub Pages at <https://sclondon.github.io/WaysideGallery/build/>.
To update it, export the **Web** preset
(`godot --headless --path . --export-release "Web" build/index.html`), commit `build/`, and push.
`art/*.json` is in the preset's include filter so the catalog ships with the build.

## Automated smoke test

```
godot --path . -- --autotest=C:/some/folder
```
Walks in, views a few pieces, saves screenshots to that folder and quits.
