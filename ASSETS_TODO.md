# Assets, Platzhalter und Entwickler-Hinweise

Alle Figuren-Sprites stammen aus den mitgelieferten Sheets (`assets/source/`), automatisch zerschnitten nach `assets/weapons|proj|icons|enemies|chars|items`.

## UI: Vector UI Pack (dobo_ui)
- Rohpaket: `Vector_UI_Pack_dobo_ui/` (per `.gdignore` vom Import ausgeschlossen, in `.gitignore`).
- Genutzte Teile: `assets/ui/` (kopiert), skalierte 9-Patch-Texturen: `assets/ui/scaled/` (erzeugt von `tools/build_ui_assets.gd`).
- Neu erzeugen: `godot --headless --path . --script res://tools/build_ui_assets.gd`
- Zentrales Theme: `UIKit.make_theme()` (`ui/ui_kit.gd`), wird in `scripts/main.gd` als Root-Theme gesetzt.
- Wichtige Helfer: `UIKit.button`, `UIKit.notebook` (Notizbuch-Fenster), `UIKit.sbox` (9-Patch-Stylebox), `UIKit.draw_bar`.
- Lizenz des Pakets beachten (nicht öffentlich weiterverteilen, falls die Lizenz das untersagt).

## Grafik (Platzhalter, prozedural bzw. 3D-Boxen)
| Was | Wo im Code | Empfohlene Größe | Ersetzen durch |
| --- | --- | --- | --- |
| Boden je Kapitel (Fliesen, Parkett, Labor, Schulhof) | `scripts/floor_painter.gd` | 1600x1020 px Textur | gemalte Boden-Texturen |
| Wandmalerei (Klassenzimmer, Labor, Bibliothek, Schulfassade) | `scripts/wall_art.gd` | Rückwand 1600x210 px, Seite 825x150 px | gemalte Wandtexturen |
| Schulbänke, Labortische, Bücherregale | `scripts/stage3d.gd` `_build_desk/_build_shelf` | 170x64 px Grundfläche | 3D-Modelle |
| Hub-Stationen (Tafel, Werkbank, Brett, Schaukasten, Schild, Spinde) | `scripts/station.gd` | ca. 150x150 px | 3D-Modelle |
| Mülleimer, Tafel (reflektiert) | `scripts/objects/` | 40x42 / 120x100 px | Sprite/Modell |
| Begleiter (Hamster/Hund/Kröte) | `Db.ags` (Rattensprite, Schaf, Frosch getönt) | 26-32 px hoch | eigene Sprites |
| Bosse Ätz / Zorn | `DbExtra._enemies` (Chemiker-Sprite, großer Frosch) | 150-170 px hoch | eigene Boss-Sprites |
| XP-Kugel, Wasser/Erbsen/Flammen-Projektile | `scripts/pickup.gd`, `scripts/projectile.gd` | 14-20 px | Sprites |
| Charaktere Justus/Tobi/Mia/Leon | `ui/char_select.gd` (Silhouetten) | 170 px hoch | Charakter-Sprites |

## Audio (alles prozedural in `scripts/autoload/sfx.gd`)
Ersetzen: `Sfx.sounds["name"] = load("res://audio/xyz.ogg")`. Audio-Busse: Music / SFX / Voice.

## Spielsysteme (Überblick)
- Hub: `Arena.hub_mode`, Stationen `scripts/station.gd`, Menüs `ui/*_screen.gd` (Skilltree, Werkbank+Rezeptbuch, Schwarzes Brett, AG, Direktorenschild).
- Meta: `scripts/autoload/save.gd` (user://save.json), Daten in `scripts/data/db_extra.gd`.
- Kapitel: `Db.chapters` (Erdgeschoss, MINT-Trakt, Bibliothek) mit eigenen Wellen, Layouts und Bossen.
- Events: `scripts/event_manager.gd` (Hitzefrei, Vokabeltest, Pausenaufsicht, Räumungsübung, Stromausfall).
- 8 Evolutionen: `Db.evolutions`, Waffenlogik `scripts/weapon_runner.gd`.

## Bewusst nicht umgesetzt
- Drag-and-Launch / RigidBody3D-Physik aus der eingefügten "Kinetic Knights"-Spec (anderes Spiel)
- Charaktere Justus/Tobi/Mia/Leon, Geheimraum "Nachsitzen", Archiv-Menü (Daten werden aber gespeichert)

## Entwickler-Tools
- Debug-Tasten: F1 +50 Geld, F2 Level-Up, F3 alle Gegner töten, F4 Gottmodus, F5 Evolutions-Waffen geben
- Bot: `godot --path . -- --autotest --god --speed=3 --shots=<ordner> [--hub] [--chapter=2] [--boss] [--evo] [--ui] [--weapons] [--event=stromausfall] [--start=water] [--proj]`
  (Bot-Läufe nutzen `user://save_autotest.json`, nie den echten Spielstand)
