extends BattleUnit
class_name MercenaryUnit

var hiring_cost: int = 500  # Стоимость найма в медяках

func _init(mercenary_name: String = "Томас"):
	unit_name = mercenary_name
	max_hp = 80
	current_hp = 80
	attack_power = 12
	defense = 6
	accuracy = 0.82
	critical_chance = 0.18
	is_player_unit = true
	is_alive = true

# Оказывает ли боевую поддержку (снижает шанс боя, помогает в бою)
func get_support_bonus() -> float:
	# Наёмник снижает шанс боя на 15%
	return 0.15
