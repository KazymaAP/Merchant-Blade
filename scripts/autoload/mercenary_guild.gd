extends Node

# Гильдия наёмников - найм боевых товарищей
# Наёмники имеют имена, характеристики, экипировку, мораль
# Могут погибнуть (перманентная смерть)

var mercenaries: Array = []  # Список нанятых наёмников
var mercenary_id_counter: int = 1

# Шаблоны наёмников (доступны в зависимости от репутации)
var mercenary_templates: Array = [
	{
		"id": "recruit",
		"name": "Новобранец",
		"titles": ["Боря", "Грош", "Панка", "Жора", "Витяй"],
		"min_reputation": 0,
		"hp": 60,
		"attack": 8,
		"defense": 3,
		"dexterity": 8,
		"price": 200
	},
	{
		"id": "soldier",
		"name": "Боевой товарищ",
		"titles": ["Саша", "Ваня", "Федя", "Костя", "Кирилл"],
		"min_reputation": 30,
		"hp": 80,
		"attack": 12,
		"defense": 6,
		"dexterity": 10,
		"price": 400
	},
	{
		"id": "veteran",
		"name": "Ветеран",
		"titles": ["Глеб", "Мстислав", "Сергей", "Юрий", "Владимир"],
		"min_reputation": 60,
		"hp": 100,
		"attack": 15,
		"defense": 10,
		"dexterity": 12,
		"price": 700
	},
	{
		"id": "master_at_arms",
		"name": "Мастер боя",
		"titles": ["Святослав", "Ярослав", "Олег Мудрый"],
		"min_reputation": 90,
		"hp": 120,
		"attack": 20,
		"defense": 15,
		"dexterity": 15,
		"price": 1200
	}
]

func _ready():
	pass

# Получить доступных наёмников (зависит от репутации)
func get_available_mercenaries(reputation: int) -> Array:
	var available = []
	for template in mercenary_templates:
		if reputation >= template["min_reputation"]:
			available.append(template)
	return available

# Нанять наёмника
func hire_mercenary(template_id: String, reputation: int, money: int) -> Dictionary:
	var template = null
	for t in mercenary_templates:
		if t["id"] == template_id:
			template = t
			break
	
	if template == null:
		return { "success": false, "error": "Шаблон не найден" }
	
	if reputation < template["min_reputation"]:
		return { "success": false, "error": "Недостаточная репутация" }
	
	if money < template["price"]:
		return { "success": false, "error": "Недостаточно денег" }
	
	# Создаём наёмника
	var merc_name = template["titles"][randi() % template["titles"].size()]
	var mercenary = {
		"id": mercenary_id_counter,
		"unique_id": "merc_%d" % mercenary_id_counter,
		"name": merc_name,
		"template": template_id,
		"hp": template["hp"],
		"max_hp": template["hp"],
		"attack_power": template["attack"],
		"defense": template["defense"],
		"dexterity": template["dexterity"],
		"fatigue": 0,
		"morale": 100,
		"is_alive": true,
		"equipment": {
			"weapon": null,
			"armor": null,
			"accessory": null
		},
		"experience": 0,
		"battles_fought": 0
	}
	
	mercenary_id_counter += 1
	mercenaries.append(mercenary)
	
	return { "success": true, "mercenary": mercenary, "cost": template["price"] }

# Получить список всех наёмников
func get_mercenary_list() -> Array:
	return mercenaries

# Получить наёмника по ID
func get_mercenary(merc_id: int) -> Dictionary:
	for merc in mercenaries:
		if merc["id"] == merc_id:
			return merc
	return {}

# Снять наёмника с должности
func dismiss_mercenary(merc_id: int) -> bool:
	for i in range(mercenaries.size()):
		if mercenaries[i]["id"] == merc_id:
			mercenaries.remove_at(i)
			return true
	return false

# Обновить мораль после боя
func update_morale(merc_id: int, battle_won: bool):
	var merc = get_mercenary(merc_id)
	if merc.is_empty():
		return
	
	if battle_won:
		merc["morale"] = mini(100, merc["morale"] + 5)
		merc["experience"] += 10
	else:
		merc["morale"] = maxi(0, merc["morale"] - 15)
		merc["experience"] += 5

# Проверить восстание (низкая мораль < 50% и случайный шанс)
func check_morale_break(merc_id: int) -> bool:
	var merc = get_mercenary(merc_id)
	if merc.is_empty():
		return false
	
	if merc["morale"] < 50 and randf() < 0.2:
		return true
	return false

# Экипировать наёмника (предмет должен существовать)
func equip_mercenary(merc_id: int, equipment_id: String) -> bool:
	var merc = get_mercenary(merc_id)
	if merc.is_empty():
		return false
	
	var equipment = EquipmentSystem.get_equipment_by_id(equipment_id)
	if equipment.is_empty():
		return false
	
	match equipment["type"]:
		"weapon":
			merc["equipment"]["weapon"] = equipment
		"armor":
			merc["equipment"]["armor"] = equipment
		"accessory":
			merc["equipment"]["accessory"] = equipment
		_:
			return false
	
	return true

# Получить боевые характеристики наёмника (с учётом экипировки и состояния)
func get_mercenary_combat_stats(merc_id: int) -> Dictionary:
	var merc = get_mercenary(merc_id)
	if merc.is_empty():
		return {}
	
	var attack = merc["attack_power"]
	var defense = merc["defense"]
	var critical = 0.05
	
	# Добавляем бонусы экипировки
	if merc["equipment"]["weapon"] != null:
		attack += merc["equipment"]["weapon"]["damage"]
		critical += merc["equipment"]["weapon"].get("critical_chance", 0)
	
	if merc["equipment"]["armor"] != null:
		defense += merc["equipment"]["armor"]["defense"]
	
	if merc["equipment"]["accessory"] != null:
		var acc = merc["equipment"]["accessory"]
		attack += acc.get("damage", 0)
		defense += acc.get("defense", 0)
		critical += acc.get("critical_chance", 0)
	
	return {
		"hp": merc["hp"],
		"max_hp": merc["max_hp"],
		"attack": attack,
		"defense": defense,
		"dexterity": merc["dexterity"],
		"fatigue": merc["fatigue"],
		"morale": merc["morale"],
		"critical_chance": critical,
		"experience": merc["experience"],
		"battles_fought": merc["battles_fought"]
	}

# Обновить дневные траты на наёмников (например, в tavern)
func update_daily_costs() -> int:
	var daily_cost = 0
	for merc in mercenaries:
		if merc["is_alive"]:
			daily_cost += 10  # 10 серебра в день за наёмника
	return daily_cost

# Погибший наёмник
func kill_mercenary(merc_id: int):
	var merc = get_mercenary(merc_id)
	if not merc.is_empty():
		merc["is_alive"] = false

# Восстановить здоровье наёмника
func heal_mercenary(merc_id: int, amount: int):
	var merc = get_mercenary(merc_id)
	if not merc.is_empty():
		merc["hp"] = mini(merc["max_hp"], merc["hp"] + amount)

# Получить статус наёмника для UI
func get_mercenary_status(merc_id: int) -> Dictionary:
	var merc = get_mercenary(merc_id)
	if merc.is_empty():
		return {}
	
	return {
		"id": merc["id"],
		"name": merc["name"],
		"template": merc["template"],
		"hp": merc["hp"],
		"max_hp": merc["max_hp"],
		"morale": merc["morale"],
		"experience": merc["experience"],
		"is_alive": merc["is_alive"],
		"weapon": merc["equipment"]["weapon"].get("name", "Кулак") if merc["equipment"]["weapon"] != null else "Кулак",
		"armor": merc["equipment"]["armor"].get("name", "Одежда") if merc["equipment"]["armor"] != null else "Одежда"
	}
