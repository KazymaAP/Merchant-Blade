extends Node

# Мастерские в городах
var workshops: Dictionary = {}  # { city_id: [{ id, type, level, production, owner_money }] }

signal workshop_bought(city_id: int, workshop_id: String)
signal workshop_upgraded(workshop_id: String)
signal production_ready(workshop_id: String, good_id: int, quantity: int)

func _ready():
	_initialize_workshops()
	print("[WorkshopManager] Инициализирована")

func _initialize_workshops():
	# По 0 мастерских в каждом городе на старте
	for city_id in range(3):
		workshops[city_id] = []

# Купить мастерскую
func buy_workshop(city_id: int, workshop_type: String) -> bool:
	if city_id < 0 or city_id >= 3:
		return false
	
	var cost = 800  # Средняя сложность
	if GameManager.money_in_copper < cost * 100:  # 800 серебра = 80000 медяков
		print("[WorkshopManager] Недостаточно денег для покупки мастерской")
		return false
	
	GameManager.add_money(-cost * 100)
	
	var workshop = {
		"id": "workshop_%s_%d" % [workshop_type, workshops[city_id].size()],
		"type": workshop_type,
		"level": 1,
		"production": _get_base_production(workshop_type),
		"production_accumulated": 0,
		"good_id": _get_good_for_workshop(workshop_type)
	}
	
	workshops[city_id].append(workshop)
	workshop_bought.emit(city_id, workshop["id"])
	print("[WorkshopManager] Куплена мастерская '%s' в городе %d" % [workshop_type, city_id])
	return true

# Получить производство за день
func produce_daily(city_id: int):
	if city_id not in workshops:
		return
	
	for workshop in workshops[city_id]:
		var daily_production = workshop["production"] * workshop["level"]
		workshop["production_accumulated"] += daily_production
		production_ready.emit(workshop["id"], workshop["good_id"], daily_production)

# Забрать продукцию
func collect_production(workshop_id: String) -> Dictionary:
	for city_id in workshops.keys():
		for workshop in workshops[city_id]:
			if workshop["id"] == workshop_id:
				var amount = workshop["production_accumulated"]
				workshop["production_accumulated"] = 0
				return { "good_id": workshop["good_id"], "quantity": amount }
	return {}

# Улучшить мастерскую
func upgrade_workshop(workshop_id: String) -> bool:
	var cost = 500  # серебра
	if GameManager.money_in_copper < cost * 100:
		return false
	
	for city_id in workshops.keys():
		for workshop in workshops[city_id]:
			if workshop["id"] == workshop_id:
				GameManager.add_money(-cost * 100)
				workshop["production"] = int(workshop["production"] * 1.5)
				workshop_upgraded.emit(workshop_id)
				print("[WorkshopManager] Мастерская '%s' улучшена" % workshop_id)
				return true
	
	return false

# Получить список мастерских города
func get_city_workshops(city_id: int) -> Array:
	return workshops.get(city_id, [])

# Получить статус
func get_status() -> Dictionary:
	var total_production = 0
	var workshop_count = 0
	
	for city_id in workshops.keys():
		workshop_count += workshops[city_id].size()
		for ws in workshops[city_id]:
			total_production += ws["production"] * ws["level"]
	
	return {
		"total_workshops": workshop_count,
		"daily_production": total_production,
		"cities": workshops.keys().size()
	}

func _get_base_production(workshop_type: String) -> int:
	match workshop_type:
		"mill": return 10  # Мельница - зерно
		"smithy": return 8  # Кузница - оружие
		"loom": return 6   # Ткацкая - ткани
		"sawmill": return 12  # Лесопилка - дерево
		_: return 5

func _get_good_for_workshop(workshop_type: String) -> int:
	match workshop_type:
		"mill": return 1  # Зерно
		"smithy": return 3  # Железо
		"loom": return 4  # Ткани
		"sawmill": return 2  # Дерево
		_: return 1
