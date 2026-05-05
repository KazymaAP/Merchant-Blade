extends Node

# Система охраны для караванов
# Охрана снижает вероятность боя

signal guard_hired(guard_type: String, cost: int)
signal guard_deserted(reason: String)

var current_guards: Array = []  # Массив активных охранников

const GUARD_TYPES = {
	"archer": {
		"name": "Лучник",
		"cost_per_day": 10,  # серебра в день
		"combat_reduction": 0.05,  # Снижает вероятность боя на 5%
		"morale": 100,
		"effectiveness": 1.0
	},
	"swordsman": {
		"name": "Мечник",
		"cost_per_day": 15,
		"combat_reduction": 0.08,
		"morale": 100,
		"effectiveness": 1.2
	},
	"knight": {
		"name": "Рыцарь",
		"cost_per_day": 25,
		"combat_reduction": 0.15,
		"morale": 100,
		"effectiveness": 1.5
	}
}

var has_commander: bool = false  # Командир охраны: +10% эффективности

func _ready():
	print("[GuardSystem] Инициализирована система охраны")

# Нанять охранника
func hire_guard(guard_type: String) -> bool:
	if guard_type not in GUARD_TYPES:
		print("[GuardSystem] Неизвестный тип охранника: %s" % guard_type)
		return false
	
	var guard_info = GUARD_TYPES[guard_type]
	var cost = guard_info["cost_per_day"]
	
	# Проверяем, достаточно ли денег
	if not GameManager.add_money(-cost):
		print("[GuardSystem] Недостаточно денег для найма охранника")
		return false
	
	var new_guard = {
		"type": guard_type,
		"name": guard_info["name"],
		"cost_per_day": cost,
		"combat_reduction": guard_info["combat_reduction"],
		"morale": guard_info["morale"],
		"effectiveness": guard_info["effectiveness"],
		"hired_day": GameManager.current_day,
		"is_alive": true
	}
	
	current_guards.append(new_guard)
	guard_hired.emit(guard_type, cost)
	print("[GuardSystem] Нанята охрана: %s (стоимость: %d серебра/день)" % [guard_info["name"], cost])
	return true

# Нанять командира охраны (+10% эффективности всей охране)
func hire_commander() -> bool:
	if has_commander:
		return false
	
	var cost = 50
	if not GameManager.add_money(-cost):
		return false
	
	has_commander = true
	print("[GuardSystem] Нанят командир охраны")
	return true

# Получить общее снижение вероятности боя
func get_combat_reduction() -> float:
	var total_reduction = 0.0
	
	for guard in current_guards:
		if guard["is_alive"]:
			var effectiveness = guard["effectiveness"]
			if has_commander:
				effectiveness *= 1.1  # +10% с командиром
			total_reduction += guard["combat_reduction"] * effectiveness
	
	# Максимальное снижение - 50%
	return min(total_reduction, 0.5)

# Получить статус охраны
func get_status() -> Dictionary:
	var total_reduction = get_combat_reduction()
	var active_guards = 0
	var daily_cost = 0
	
	for guard in current_guards:
		if guard["is_alive"]:
			active_guards += 1
			daily_cost += guard["cost"]
	
	return {
		"active_guards": active_guards,
		"total_guards": current_guards.size(),
		"combat_reduction": total_reduction,
		"daily_cost": daily_cost,
		"guards": current_guards.duplicate()
	}
func update_morale_after_battle(player_won: bool):
	for guard in current_guards:
		if guard["is_alive"]:
			if player_won:
				guard["morale"] = min(100, guard["morale"] + 10)
			else:
				guard["morale"] = max(0, guard["morale"] - 15)
				
				# При морали < 50% может быть восстание (шанс 20%)
				if guard["morale"] < 50 and randf() < 0.2:
					guard["is_alive"] = false
					# Охрана забирает товар (10-30%)
					var stolen_percent = randi_range(10, 30)
					var stolen_value = int(GameManager.get_inventory_value() * stolen_percent / 100)
					GameManager.add_money(-stolen_value)  # Мы теряем товар (вычитаем деньги)
					guard_deserted.emit("Восстание охраны (украдено %d%%)" % stolen_percent)
					print("[GuardSystem] Охранник %s восстал и украл %d%% товара" % [guard["name"], stolen_percent])

# Обновить дневные расходы на охрану
func update_daily() -> int:
	var daily_cost = 0
	for guard in current_guards:
		if guard["is_alive"]:
			daily_cost += guard["cost_per_day"]
	
	if has_commander:
		daily_cost += 10  # 10 серебра в день за командира
	
	return daily_cost

# Получить список охранников
func get_guards_list() -> Array:
	return current_guards.duplicate()

# Получить количество живых охранников
func get_active_guard_count() -> int:
	var count = 0
	for guard in current_guards:
		if guard["is_alive"]:
			count += 1
	return count

# Расходы на содержание охраны (вычисляется при путешествии)
func calculate_guard_costs() -> int:
	return update_daily()

# Распустить охранника
func dismiss_guard(guard_index: int) -> bool:
	if guard_index < 0 or guard_index >= current_guards.size():
		return false
	
	var guard = current_guards[guard_index]
	# Возвращаем половину стоимости
	var refund = int(guard["cost"] / 2)
	GameManager.add_money(refund)
	
	current_guards.remove_at(guard_index)
	print("[GuardSystem] Охранник распущен, возвращено %d медяков" % refund)
	return true

# Очистить охрану (при перезагрузке или других событиях)
func clear_guards():
	current_guards.clear()
