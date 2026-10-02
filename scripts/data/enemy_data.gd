class_name EnemyData
extends Resource
## Datensatz eines Gegnertyps.

@export var id := ""
@export var display_name := ""
@export var hp := 20.0
@export var speed := 60.0
@export var contact_damage := 8.0
@export var textures: PackedStringArray = PackedStringArray()
@export var tex_alt := ""            # Warnpose (z.B. offener Mund)
@export var height := 50.0           # Zielhoehe in Pixeln
@export var faces_right := true
@export var behavior := "chase"      # chase | hop | charge | shoot | lob | slam | boss
@export var radius := 14.0
@export var xp := 3
@export var coin_chance := 0.3
@export var coin_value := 1
@export var material := "slime"      # slime | paper | fur | glass | cloth | meat
@export var elite := false
@export var params := {}
