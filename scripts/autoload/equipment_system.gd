extends Node

# Торговец оружием в каждом городе
# Слоты экипировки: оружие, броня, аксессуар

var equipment_database: Array = [
	# ОРУЖИЕ
	{
		"id": "stick",
		"name": "Дубина",
		"type": "weapon",
		"damage": 5,
		"critical_chance": 0.0,
		"range": 1,
		"price": 100
	},
	{
		"id": "sword_iron",
		"name": "Железный меч",
		"type": "weapon",
		"damage": 15,
		"critical_chance": 0.05,
		"range": 1,
		"price": 500
	},
	{
		"id": "sword_steel",
		"name": "Стальной меч",
		"type": "weapon",
		"damage": 20,
		"critical_chance": 0.08,
		"range": 1,
		"price": 1000
	},
	{
		"id": "crossbow",
		"name": "Арбалет",
		"type": "weapon",
		"damage": 18,
		"critical_chance": 0.1,
		"range": 5,
		"cooldown": 2,  # Стреляет раз в 2 хода
		"price": 800
	},
	
	# БРОНЯ
	{
		"id": "armor_leather",
		"name": "Кожаная броня",
		"type": "armor",
		"defense": 5,
		"price": 300
	},
	{
		"id": "armor_chainmail",
		"name": "Кольчуга",
		"type": "armor",
		"defense": 10,
		"price": 600
	},
	{
		"id": "armor_plate",
		"name": "Латные доспехи",
		"type": "armor",
		"defense": 15,
		"price": 1200
	},
	
	# АКСЕССУАРЫ
	{
		"id": "ring_strength",
		"name": "Кольцо Силы",
		"type": "accessory",
		"damage": 3,
		"price": 400
	},
	{
		"id": "ring_protection",
		"name": "Кольцо Защиты",
		"type": "accessory",
		"defense": 3,
		"price": 400
	},
	{
		"id": "amulet_luck",
		"name": "Амулет Удачи",
		"type": "accessory",
		"critical_chance": 0.05,
		"price": 500
	}
]

# Экипировка юнитов: { unit_id: { "weapon": {}, "armor": {}, "accessory": {} } }
var player_equipment: Dictionary = {
	"weapon": null,
	"armor": null,
	"accessory": null
}

var mercenary_equipment: Dictionary = {}  # { merc_id: { weapon, armor, accessory } }

func _ready():
	pass

# Получить доступное оружие в городе
func get_equipment_shop(city_index: int) -> Array:
	# Все товары доступны везде (можно расширить позже)
	return equipment_database

# Получить стоимость экипировки с учётом репутации
func get_equipment_price(equipment_id: String, reputation: int) -> int:
	var equipment = get_equipment_by_id(equipment_id)
	if equipment == null:
		return 0
	
	var base_price = equipment["price"]
	# При низкой репутации цена выше на 10%, при высокой скидка 10%
	var price_modifier = 1.0 + (reputation / 100.0) * -0.1  # Минус 0.1% за каждое очко
	return int(base_price * price_modifier)

# Купить экипировку
func buy_equipment(unit_id: int, equipment_id: String, money: int) -> bool:
	var equipment = get_equipment_by_id(equipment_id)
	if equipment == null:
		return false
	
	var price = equipment["price"]
	if money < price:
		return false
	
	# Экипировать юнита
	if unit_id == 0:  # Игрок
		match equipment["type"]:
			"weapon":
				player_equipment["weapon"] = equipment
			"armor":
				player_equipment["armor"] = equipment
			"accessory":
				player_equipment["accessory"] = equipment
	else:
		if not mercenary_equipment.has(unit_id):
			mercenary_equipment[unit_id] = {}
		
		match equipment["type"]:
			"weapon":
				mercenary_equipment[unit_id]["weapon"] = equipment
			"armor":
				mercenary_equipment[unit_id]["armor"] = equipment
			"accessory":
				mercenary_equipment[unit_id]["accessory"] = equipment
	
	return true

# Применить бонусы экипировки к юниту
func apply_equipment_bonus(unit: BattleUnit):
	# Получить экипировку юнита
	var equipment_set = null
	if unit.is_player_unit:
		equipment_set = player_equipment
	else:
		equipment_set = mercenary_equipment.get(unit.unit_name, {})
	
	if equipment_set == null:
		return
	
	# Оружие
	if equipment_set.has("weapon") and equipment_set["weapon"] != null:
		var weapon_data = {
			"name": equipment_set["weapon"]["name"],
			"damage": equipment_set["weapon"]["damage"],
			"critical_chance": equipment_set["weapon"].get("critical_chance", 0),
			"range": equipment_set["weapon"].get("range", 1)
		}
		unit.equip_weapon(weapon_data)
	
	# Броня
	if equipment_set.has("armor") and equipment_set["armor"] != null:
		var armor_data = {
			"name": equipment_set["armor"]["name"],
			"defense": equipment_set["armor"]["defense"]
		}
		unit.equip_armor(armor_data)
	
	# Аксессуар
	if equipment_set.has("accessory") and equipment_set["accessory"] != null:
		var accessory = equipment_set["accessory"]
		if accessory.has("damage"):
			unit.attack_power += accessory["damage"]
		if accessory.has("defense"):
			unit.defense += accessory["defense"]
		if accessory.has("critical_chance"):
			unit.critical_chance += accessory["critical_chance"]

# Получить экипировку по ID
func get_equipment_by_id(equipment_id: String) -> Dictionary:
	for equipment in equipment_database:
		if equipment["id"] == equipment_id:
			return equipment
	return {}

# Получить экипировку юнита
func get_unit_equipment(unit_id: int) -> Dictionary:
	if unit_id == 0:  # Игрок
		return player_equipment
	return mercenary_equipment.get(unit_id, {})

# Получить статы экипировки
func get_equipment_stats(equipment_id: String) -> Dictionary:
	var equipment = get_equipment_by_id(equipment_id)
	if equipment == null:
		return {}
	
	return {
		"damage": equipment.get("damage", 0),
		"defense": equipment.get("defense", 0),
		"critical_chance": equipment.get("critical_chance", 0),
		"range": equipment.get("range", 1)
	}

# Снять экипировку
func unequip(unit_id: int, slot: String) -> bool:
	if unit_id == 0:
		if player_equipment.has(slot):
			player_equipment[slot] = null
			return true
	else:
		if mercenary_equipment.has(unit_id) and mercenary_equipment[unit_id].has(slot):
			mercenary_equipment[unit_id][slot] = null
			return true
	
	return false
