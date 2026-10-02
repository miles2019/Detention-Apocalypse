class_name HubInfo
extends RefCounted
## Hilfsfunktionen für den Hub: Hinweis-Abzeichen ("!") an Stationen.

static func station_badge(kind: String) -> bool:
	match kind:
		"skills":
			for id in Db.skills:
				if Save.skill_level(id) < Db.skills[id].max_level and Save.data.passes >= Save.skill_cost(id):
					return true
		"workbench":
			for id in Db.start_weapon_cost:
				if not Save.weapon_unlocked(id) and Save.data.passes >= Db.start_weapon_cost[id]:
					return true
		"board":
			return Save.claimable_count() > 0
		"ag":
			for id in Db.ags:
				if not Save.ag_unlocked(id) and Save.data.marken >= Db.ags[id].cost:
					return true
		"director":
			return Save.data.runs == 0
	return false
