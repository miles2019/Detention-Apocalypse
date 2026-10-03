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

## Performance
- Gegner-Separation und Projektil-Treffer nutzen ein Raster (`Arena.enemies_near`, CELL=64) statt O(n²).
- `SpriteBatch` (scripts/sprite_batch.gd): Gegner, Münzen, Heil- und XP-Pickups sowie ihre Schatten werden über je ein MultiMesh gezeichnet (Textur-Atlas, Shader `batch_sprite`/`batch_shadow`). Neue Gegnertexturen werden automatisch in den Atlas aufgenommen (Db.enemies).
- Musik wird beim Start in einem Hintergrund-Thread erzeugt (kein Hänger beim ersten Track).
- Bot-Flag `--stress`: füllt die Arena bis 70 Gegner und loggt `[PERF]`-Frame-Statistiken (Max-Werte werden durch Hitstop-Zeitskalierung verfälscht, avg/p95 beachten).

## Neu: Bedienung, Wegfindung, Inhalte
- **Zeugnis** (ui/result_screen.gd): zweispaltig, Buttons fest am unteren Rand (auch `R` = nochmal, `Enter` = Schulhof). Sechs Fachnoten + Gesamtnote, im Endlos-Modus mit Bestenliste.
- **Hover-Infos** (ui/tooltip.gd, ui/tips.gd, `UIKit.tip(control, titel, text)`): Waffen mit echten Werten je Stufe, Items, Fach-Sets, Werte.
- **Schülerakte** (ui/stats_screen.gd): `Tab` im Run, Button im Pausemenü und im Kiosk.
- **Waffen verkaufen** im Kiosk (`Player.sell_weapon`), die letzte Waffe ist gesperrt.
- **Klassenarbeit**: Neu würfeln (`R`), Bannen, Merken – je Run begrenzt (`Game.lv_rerolls/lv_bans/lv_locks`).
- **Wegfindung** (scripts/arena.gd, Abschnitt "Wegfindung"): Flussfeld per Breitensuche vom Spieler aus (Raster 32 px, getrennt für kleine/große Gegner), direkte Linie bei freier Sicht, Seitwärtsschritt als Notlösung. Bosse zertrümmern Hindernisse (`Arena.smash_obstacles`).
- **Zerstörbare Umgebung**: Tische/Regale (`Arena.blast`), Feuerlöscher und Chemieschränke (scripts/objects/arena_prop.gd, 3D-Platzhalter).
- **Elite-Affixe** (`Db.affixes`), **Fach-Sets** mit zwei Stufen (`Db.sets`), **Endlos-Modus** (`Game.endless`, `DbExtra.endless_wave`).
- **Charaktere** (`Db.characters`): Frau Kelle und Herr Probe nutzen vorerst die eingefärbte Scrubbs-Grafik – **Platzhalter, eigene Sprites fehlen** (assets/chars/). Tobi und Mia sind leere Plätze.
- **Projektil-Schweife**: scripts/trail_pool.gd (MultiMesh) statt `GPUParticles3D.emit_particle`, das der Compatibility-Renderer nicht unterstützt.
- Bot-Flags neu: `--feat` (Verkauf, Tooltip, Akte, Würfeln/Bannen/Merken), `--smash`, `--navtest`, `--endless`, `--fast`, `--stopwave=N`, `--char=<id>`.

## 3D-Modelle (assets/models, Lizenzen in CREDITS.md)
- `scripts/model_lib.gd` lädt Objekte aus den FBX-Paketen und fasst ihre Teil-Meshes zu einem Mesh zusammen.
- **Im Spiel:** Klassenzimmer (Kapitel 1) nutzt Schülertische, Stühle, Lehrerpult und Heft aus `classroom.fbx`; alle Mülleimer nutzen `trash_can.fbx`.
- **Noch Platzhalter:** Labortische (Kapitel 2), Bibliothek (Regale, Tisch), Tafel, Feuerlöscher, Chemieschrank.
- **Nicht verwendet:** `interior_walls.fbx` und `walls_lowpoly/` (kommen ohne zugewiesene Texturen an, die bemalten Wände passen besser zum Stil); `bookcase`/`small_bookcase` (43.000–92.000 Dreiecke); `blackboard`, `door`, `clock` (einfarbige Platten ohne Details).
- Die Original-Archive liegen in `source/` (von Godot und Git ausgenommen).

## Waffen-Ausbau
- **Kiosk** bietet jetzt alle Waffen an (die Werkbank schaltet nur noch Startwaffen frei): 3 Waffen + 2 Items, möglichst unterschiedliche Spielweisen.
- **Merken** sitzt an den Waffenkarten im Kiosk (`Game.shop_locks`, höchstens 2), nicht mehr bei der Klassenarbeit.
- **Neue Waffentypen** (scripts/weapon_runner.gd): `mine` (scripts/trap.gd), `vortex` (scripts/vortex.gd + effects/vortex.gdshader), `boomerang`, `turret` (scripts/turret.gd), `fissure`; Projektil-Parameter `snipe`, `seek`, `explode`/`cloud`, `still`; Nahkampf-Parameter `reflect`, `launch`, `shred`, `sweep`; Kegel-Parameter `paint`.
- **Statuseffekte** (scripts/enemy.gd, Abschnitt "Statuseffekte"): nass (Waffen-Tag `water`) und brennend (Tag `fire`) reagieren zu einer Dampfexplosion. Darstellung über `effects/batch_sprite.gdshader` (brennt / nass / gefroren).
- Bot-Flags neu: `--weapons` testet jede Waffe 3,5 s, `--also=id1,id2` rüstet Zusatzwaffen aus. `--stress` misst jetzt echte Framezeit per Uhr.
- **Styloo-Paket** (assets/models/styloo): Labortische mit Kolben/Globus (Kapitel 2), Schreibtisch des Rektors mit Pflanze (Kapitel 3), Feuerlöscher (alle Kapitel). Bewusst nicht verwendet: Regal und Schrank (aus der Spielperspektive nur braune Kisten – die eigenen Regale mit Buchrücken und der Chemieschrank mit Kolben sind besser lesbar), Wandmodule.
- **Bodentexturen** (assets/textures): Kacheln im Labor, Holz in der Bibliothek, Gras im Schulhof. Sie werden in `Db._ready` vorab geladen, weil der Boden nur einmal gezeichnet wird.
- `tools/preview_models.gd`: rendert alle .glb eines Ordners als Übersichtsbild.
