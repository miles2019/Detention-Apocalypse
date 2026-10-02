class_name WeaponData
extends Resource
## Datensatz einer Waffe. Alle Balancing-Werte liegen hier (siehe Db.weapons).

@export var id := ""
@export var display_name := ""
@export var subject := ""
@export var kind := "bullet"       # bullet | flame | melee | ring | lob | steam
@export var damage := 10.0
@export var cooldown := 1.0
@export var reach := 300.0         # Zielreichweite / Radius
@export var speed := 500.0
@export var count := 1
@export var pierce := 0
@export var bounce := 0
@export var knockback := 100.0
@export var spread := 10.0
@export var color := Color.WHITE
@export var icon := ""
@export var proj_icon := ""
@export var proj_scale := 0.5
@export var tags := PackedStringArray()
@export var desc := ""
@export var price := 10
@export var fire_sfx := "shoot_water"
@export var max_level := 3
@export var evolution := false
