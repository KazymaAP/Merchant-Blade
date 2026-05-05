extends BattleUnit
class_name PlayerUnit

func _init():
	unit_name = "Торговец"
	max_hp = 100
	current_hp = 100
	attack_power = 10
	defense = 5
	accuracy = 0.85
	critical_chance = 0.25
	is_player_unit = true
	is_alive = true
