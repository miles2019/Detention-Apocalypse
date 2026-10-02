# Platzhalter, die später durch eigene Assets ersetzt werden können

Alle Sprites stammen aus den mitgelieferten Sheets (`assets/source/`), automatisch zerschnitten nach `assets/weapons|proj|icons|enemies|chars|items`.

## Grafik (Platzhalter, prozedural bzw. 3D-Boxen)
| Was | Wo im Code | Empfohlene Größe | Ersetzen durch |
| --- | --- | --- | --- |
| Boden (Fliesen, Farbspritzer, Papierhaufen) | `scripts/floor_painter.gd` | 1600x1020 px Textur | gemalte Boden-Textur |
| Wandmalerei (Fenster, Türen, Spinde, Pinnwand) | `scripts/wall_art.gd` | Rückwand 1600x210 px, Seite 825x150 px | gemalte Wandtexturen |
| Schulbänke | `scripts/stage3d.gd` `_build_desk()` | 170x64 px Grundfläche | 3D-Modell |
| Mülleimer | `scripts/objects/trash_bin.gd` | 40x42 px | Sprite/Modell |
| Tafel (reflektiert) | `scripts/objects/chalkboard.gd` | 120x100 px | Sprite/Modell |
| XP-Kugel | `scripts/pickup.gd` (Kreis-Gradient) | 16x16 px | Icon |
| Wasser/Erbsen/Flammen-Projektile | `scripts/projectile.gd` (3D-Kugeln) | 14-20 px | Sprites |
| Charaktere Justus/Tobi/Mia/Leon | `ui/char_select.gd` (Silhouetten) | 150 px hoch | Charakter-Sprites |
| Rektor-Icon im Banner | `ui/hud.gd` (Megafon-Icon) | 44x44 px | Portrait |

## Audio (alles prozedural in `scripts/autoload/sfx.gd`)
Glocke, Fach-Jingles, Rektor-Gemurmel, Treffer, Kauf, Musik ("menu", "run").
Ersetzen: `Sfx.sounds["name"] = load("res://audio/xyz.ogg")`. Audio-Busse: Music / SFX / Voice.

## Bewusst nicht umgesetzt
- Drag-and-Launch / RigidBody3D-Physik aus der eingefügten "Kinetic Knights"-Spec (anderes Spiel)
- Spind-Verstecken (entfernt: Spind-Monster sind Gegner)
- Archiv, Schulhof-Hub, Geheimraum "Nachsitzen", AGs/Haustiere, Zeugnis-Penalty
- Weitere Räume und Fachphasen (Musik, Kunst, Mathe), Völkerbälle/Trampoline

## Entwickler-Tools
- Debug-Tasten: F1 +50 Geld, F2 Level-Up, F3 alle Gegner töten, F4 Gottmodus, F5 Evolutions-Waffen geben
- Bot: `godot --path . -- --autotest --god --speed=3 --shots=<ordner> [--boss] [--evo] [--ui] [--locker]`
