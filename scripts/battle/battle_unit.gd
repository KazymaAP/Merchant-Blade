class_name BattleUnit

# Статы юнита
var unit_name: String
var max_hp: int
var current_hp: int
var attack_power: int
var defense: int
var accuracy: float = 0.8  # Шанс попадания (0-1)
var critical_chance: float = 0.05  # Шанс крита (5% база)
var dexterity: int = 10  # Ловкость для убегания
var position: Vector2i = Vector2i.ZERO  # Позиция на сетке

# Состояние боя
var fatigue: int = 0  # 0-100 (точность -2% за 10 усталости)
var is_alive: bool = true
var is_player_unit: bool = false

# Экипировка
var weapon: Dictionary = {}  # { "name": "Меч", "damage": 15 }
var armor: Dictionary = {}   # { "name": "Кольчуга", "defense": 10 }

signal hp_changed(new_hp: int)
signal unit_died(unit_name: String)
signal attacked(attacker: String, damage: int, is_critical: bool)
signal fatigue_changed(new_fatigue: int)

func _init():
	current_hp = max_hp

# Получить текущую защиту (броня + статы)
func get_defense() -> int:
	var total_defense = defense
	if armor.has("defense"):
		total_defense += armor["defense"]
	return total_defense

# Получить текущий урон (оружие + статы)
func get_damage() -> int:
	var total_damage = attack_power
	if weapon.has("damage"):
		total_damage += weapon["damage"]
	return total_damage

# Получить точность с учётом усталости (-2% за 10 усталости)
func get_accuracy() -> float:
	var fatigue_penalty = (fatigue / 10) * 0.02
	return max(0.1, accuracy - fatigue_penalty)

# Получить урон с учётом усталости (-5% урона за 10 усталости)
func get_fatigue_damage_modifier() -> float:
	var fatigue_penalty = (fatigue / 10) * 0.05
	return max(0.5, 1.0 - fatigue_penalty)

# Проверить критический удар (5% база + бонус оружия)
func calculate_critical() -> bool:
	var crit = critical_chance
	if weapon.has("critical_chance"):
		crit += weapon["critical_chance"]
	return randf() < crit

# Атаковать другого юнита
func attack(target: BattleUnit) -> Dictionary:
	if not is_alive:
		return { "hit": false, "damage": 0, "critical": false }
	
	# Проверяем попадание с учётом усталости
	var hit_roll = randf()
	if hit_roll > get_accuracy():
		return { "hit": false, "damage": 0, "critical": false }
	
	# Рассчитываем базовый урон
	var base_damage = get_damage()
	var target_defense = target.get_defense()
	
	# Защита снижает урон на 30-50%
	var defense_reduction = target_defense * 0.3
	var final_damage = max(1, base_damage - int(defense_reduction))
	
	# Применяем штраф усталости на урон
	final_damage = int(float(final_damage) * get_fatigue_damage_modifier())
	
	# Проверяем крит
	var is_critical = calculate_critical()
	if is_critical:
		final_damage = int(final_damage * 1.5)  # Крит наносит 150% урона
	
	# Наносим урон и добавляем усталость атакующему
	target.take_damage(final_damage)
	take_fatigue(10)
	attacked.emit(unit_name, final_damage, is_critical)
	
	return {
		"hit": true,
		"damage": final_damage,
		"critical": is_critical,
		"weapon": weapon.get("name", "Кулак"),
		"attacker": unit_name,
		"target": target.unit_name
	}

# Получить урон
func take_damage(damage: int):
	current_hp = maxi(0, current_hp - damage)
	hp_changed.emit(current_hp)
	
	if current_hp <= 0:
		is_alive = false
		unit_died.emit(unit_name)

# Лечение (еда, травы, отдых)
func heal(amount: int):
	if not is_alive:
		return
	current_hp = mini(max_hp, current_hp + amount)
	hp_changed.emit(current_hp)

# Использовать лечебный предмет (трава +5-15 HP, еда +2-10 HP)
func use_healing_item(item_id: int) -> bool:
	if not is_alive or current_hp >= max_hp:
		return false
	
	var heal_amount = 0
	match item_id:
		1: # Трава
			heal_amount = randi_range(5, 15)
		2: # Еда
			heal_amount = randi_range(2, 10)
		_:
			return false
	
	heal(heal_amount)
	take_fatigue(-5)  # Лечение снимает немного усталости
	return true

# Добавить усталость (например, после атаки +10)
func take_fatigue(amount: int):
	fatigue = clampi(fatigue + amount, 0, 100)
	fatigue_changed.emit(fatigue)

# Убрать усталость (например, при отдыхе -30)
func reduce_fatigue(amount: int):
	fatigue = clampi(fatigue - amount, 0, 100)
	fatigue_changed.emit(fatigue)

# Попытка убежать из боя (зависит от ловкости)
func try_escape() -> bool:
	# Шанс убежать: 10% база + 2% за каждый пункт ловкости, -5% за каждые 10 усталости
	var base_chance = 0.1
	var dexterity_bonus = (dexterity / 5.0) * 0.02
	var fatigue_penalty = (fatigue / 10) * 0.05
	var escape_chance = base_chance + dexterity_bonus - fatigue_penalty
	return randf() < clamp(escape_chance, 0.05, 0.9)

# Отдыхать (пропуск хода, снимает 30 усталости)
func rest():
	reduce_fatigue(30)
	return { "action": "rest", "fatigue_reduced": 30 }

# Получить статус (для UI)
func get_status() -> Dictionary:
	return {
		"name": unit_name,
		"hp": current_hp,
		"max_hp": max_hp,
		"hp_percent": float(current_hp) / float(max_hp),
		"fatigue": fatigue,
		"fatigue_percent": float(fatigue) / 100.0,
		"is_alive": is_alive,
		"weapon": weapon.get("name", "Кулак"),
		"armor": armor.get("name", "Одежда"),
		"position": position,
		"accuracy_penalty": -((fatigue / 10) * 2)  # % потери точности
	}

# Экипировать оружие
func equip_weapon(weapon_data: Dictionary):
	weapon = weapon_data
	attack_power = weapon_data.get("base_attack", attack_power)

# Экипировать броню
func equip_armor(armor_data: Dictionary):
	armor = armor_data
	defense = armor_data.get("base_defense", defense)

# Переместиться на новую позицию
func move_to(new_position: Vector2i) -> bool:
	position = new_position
	return true

# Получить расстояние до другого юнита
func distance_to(other_unit: BattleUnit) -> int:
	return maxi(abs(position.x - other_unit.position.x), 
	           abs(position.y - other_unit.position.y))

# Может ли атаковать другого юнита (расстояние зависит от оружия)
func can_attack(target: BattleUnit) -> bool:
	var range_distance = weapon.get("range", 1)  # 1 для меча, 3 для лука
	return distance_to(target) <= range_distance and is_alive and target.is_alive
