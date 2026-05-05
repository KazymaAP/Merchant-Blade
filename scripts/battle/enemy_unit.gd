extends BattleUnit
class_name EnemyUnit

var loot: Dictionary = {}  # { "good_id": quantity, ... } - добыча при победе

func _init(enemy_type: String = "bandit", difficulty: int = 1):
	is_player_unit = false
	
	# Масштабируем характеристики по сложности
	match enemy_type:
		"bandit":
			unit_name = "Разбойник"
			max_hp = 50 + (difficulty * 10)
			attack_power = 8 + (difficulty * 2)
			defense = 3 + difficulty
			accuracy = 0.75
			critical_chance = 0.15
			loot = { "copper": randi_range(100, 300) * difficulty }
		
		"brigand":
			unit_name = "Бандит"
			max_hp = 70 + (difficulty * 15)
			attack_power = 12 + (difficulty * 3)
			defense = 5 + (difficulty * 2)
			accuracy = 0.80
			critical_chance = 0.20
			loot = { "copper": randi_range(200, 500) * difficulty }
		
		"marauder":
			unit_name = "Разоритель"
			max_hp = 100 + (difficulty * 20)
			attack_power = 15 + (difficulty * 4)
			defense = 7 + (difficulty * 2)
			accuracy = 0.85
			critical_chance = 0.25
			loot = { "copper": randi_range(500, 1000) * difficulty }
	
	current_hp = max_hp
	is_alive = true
