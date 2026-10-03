class_name Tips
extends RefCounted
## Texte für Hover-Infos: Waffen (mit echten Werten je Stufe), Items, Fach-Sets, Charakterwerte.

const KIND_NAMES := {
	melee = "Nahkampf", slam = "Rundumschlag", flame = "Flammenstrahl", bullet = "Projektil", ring = "Schallwelle",
	lob = "Wurf (Fläche)", steam = "Dampfwolke", ball = "Prallball", cone = "Sprühkegel", orbit = "Umlaufbahn",
}

static func set_info(subject: String, count: int = -1) -> String:
	if not Db.sets.has(subject):
		return ""
	var s: Array = Db.sets[subject]
	var head := "Fach-Set %s" % subject
	if count >= 0:
		head += " (%d Teile)" % count
	return "%s\n  ab 2: %s\n  ab 4: %s" % [head, s[0], s[1]]

## Waffen-Info. level = angezeigte Stufe; pl = Spieler (für echte Werte inkl. Boni), darf null sein.
static func weapon(wd: WeaponData, level: int = 1, pl = null, show_next: bool = true) -> String:
	var dmg_mult: float = pl.dmg_mult if pl != null else 1.0
	var atk: float = pl.atk_speed if pl != null else 1.0
	var lines: Array = [wd.desc, ""]
	lines.append("Fach: %s   ·   Typ: %s" % [wd.subject, KIND_NAMES.get(wd.kind, wd.kind)])
	var d := wd.damage * (1.0 + 0.3 * float(level - 1)) * dmg_mult
	var cd := wd.cooldown * pow(0.9, float(level - 1)) / atk
	if wd.kind == "orbit":
		lines.append("Schaden: %d je Treffer   ·   dauerhaft aktiv" % int(round(d)))
	elif wd.damage > 0.0:
		lines.append("Schaden: %d   ·   alle %.2f s   ·   %.0f pro Sek." % [int(round(d)), cd, d * float(maxi(1, wd.count)) / maxf(0.05, cd)])
	else:
		lines.append("Kein Schaden   ·   alle %.2f s" % cd)
	var extra: Array = ["Reichweite: %d" % int(wd.reach)]
	if wd.kind in ["bullet", "flame"]:
		var n: int = wd.count + (pl.extra_proj if pl != null else 0) + (1 if level >= 3 else 0)
		if n > 1:
			extra.append("Projektile: %d" % n)
	if wd.pierce > 0:
		extra.append("Durchschlag: %d" % wd.pierce)
	if wd.bounce > 0:
		extra.append("Abpraller: %d" % wd.bounce)
	if wd.knockback >= 200.0:
		extra.append("starker Rückstoß")
	lines.append("   ·   ".join(extra))
	if wd.evolution:
		lines.append("Evolutionswaffe")
	else:
		lines.append("Stufe %d / %d" % [level, wd.max_level])
		if show_next and level < wd.max_level:
			var nx := "Nächste Stufe: +30 % Schaden, 10 % schneller"
			if level + 1 >= 3 and wd.kind in ["bullet", "flame"]:
				nx += ", +1 Projektil"
			lines.append(nx)
		for r in Db.evolutions:
			if r.a == wd.id or r.b == wd.id:
				var other: String = r.b if r.a == wd.id else r.a
				lines.append("Evolution: + %s (beide Stufe 2) = %s" % [Db.weapons[other].display_name, Db.weapons[r.result].display_name])
	var si := set_info(wd.subject, pl.subject_counts.get(wd.subject, 0) if pl != null else -1)
	if si != "":
		lines.append("")
		lines.append(si)
	return "\n".join(lines)

static func item(u: UpgradeData, owned: int = 0, pl = null) -> String:
	var lines: Array = [u.desc, "", "Fach: %s" % (u.subject if u.subject != "" else "Allgemein")]
	if owned > 0:
		lines.append("Im Besitz: x%d" % owned)
	var si := set_info(u.subject, pl.subject_counts.get(u.subject, 0) if pl != null else -1)
	if si != "":
		lines.append("")
		lines.append(si)
	return "\n".join(lines)

## Was ein Upgrade konkret ändert (aktueller Wert -> neuer Wert)
static func upgrade_change(id: String, pl) -> String:
	if pl == null:
		return ""
	match id:
		"atk_speed": return "Angriffstempo: %d %% → %d %%" % [int(round(pl.atk_speed * 100.0)), int(round(pl.atk_speed * 115.0))]
		"move_speed": return "Tempo: %d → %d" % [int(pl.move_speed()), int(pl.move_speed() + Player.BASE_SPEED * float(pl.char_data.speed) * 0.1)]
		"max_hp": return "Leben: %d → %d" % [int(pl.max_hp), int(pl.max_hp + 20.0)]
		"crit": return "Krit-Chance: %d %% → %d %%" % [int(round(pl.crit * 100.0)), int(round((pl.crit + 0.1) * 100.0))]
		"proj": return "Extra-Projektile: %d → %d" % [pl.extra_proj, pl.extra_proj + 1]
		"magnet": return "Sammelradius: %d → %d" % [int(pl.magnet), int(pl.magnet + 60.0)]
		"dmg": return "Schaden: %d %% → %d %%" % [int(round(pl.dmg_mult * 100.0)), int(round((pl.dmg_mult + 0.12) * 100.0))]
		"heal": return "Leben: %d → %d" % [int(pl.hp), int(minf(pl.max_hp, pl.hp + pl.max_hp * 0.35))]
		"goggles": return "Leben: %d → %d, Schaden +8 %%" % [int(pl.max_hp), int(pl.max_hp + 20.0)]
		"flask": return "Schaden: %d %% → %d %%" % [int(round(pl.dmg_mult * 100.0)), int(round((pl.dmg_mult + 0.15) * 100.0))]
	return ""
