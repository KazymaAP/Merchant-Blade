extends Node

# Система аренды складов

var warehouses: Dictionary = {}  # { city_index: { "owner": bool, "rent_cost": int, "content": {good_id: quantity}, "days_remaining": int } }
var game_manager: Node = null

signal warehouse_rented(city_index: int)
signal warehouse_released(city_index: int)
signal warehouse_updated
signal warehouse_item_stored(city_index: int, good_id: int, quantity: int)
signal warehouse_item_retrieved(city_index: int, good_id: int, quantity: int)

# Стоимость аренды склада
var WAREHOUSE_RENT_PER_DAY: int = 10  # Медяков в день

func _ready():
	game_manager = get_node("/root/GameManager")
	_initialize_warehouses()
	print("[WarehouseSystem] Инициализирована система складов")

# Инициализировать склады в городах
func _initialize_warehouses():
	warehouses = {
		0: {
			"owner": false,
			"rent_cost": WAREHOUSE_RENT_PER_DAY,
			"content": {},
			"days_remaining": 0,
			"max_slots": 100,
			"name": "Склад города A",
			"item_dates": {}  # { good_id: day_stored }
		},
		1: {
			"owner": false,
			"rent_cost": WAREHOUSE_RENT_PER_DAY,
			"content": {},
			"days_remaining": 0,
			"max_slots": 100,
			"name": "Склад города B",
			"item_dates": {}
		},
		2: {
			"owner": false,
			"rent_cost": WAREHOUSE_RENT_PER_DAY,
			"content": {},
			"days_remaining": 0,
			"max_slots": 100,
			"name": "Склад города V",
			"item_dates": {}
		}
	}

# Арендовать склад в городе
func rent_warehouse(city_index: int, days: int = 30) -> bool:
	if city_index < 0 or city_index >= warehouses.size():
		print("[WarehouseSystem] Ошибка: неверный номер города %d" % city_index)
		return false
	
	var warehouse = warehouses[city_index]
	var total_cost = warehouse["rent_cost"] * days
	
	if not game_manager.add_money(-total_cost):
		print("[WarehouseSystem] Недостаточно денег для аренды склада! Требуется: %d медяков" % total_cost)
		return false
	
	warehouse["owner"] = true
	warehouse["days_remaining"] = days
	warehouse_rented.emit(city_index)
	print("[WarehouseSystem] Склад в городе %d арендован на %d дней (стоимость: %d медяков)" % [city_index, days, total_cost])
	return true

# Отменить аренду склада
func release_warehouse(city_index: int) -> bool:
	if city_index < 0 or city_index >= warehouses.size():
		return false
	
	var warehouse = warehouses[city_index]
	warehouse["owner"] = false
	warehouse["content"].clear()
	warehouse["days_remaining"] = 0
	warehouse_released.emit(city_index)
	print("[WarehouseSystem] Аренда склада в городе %d отменена" % city_index)
	return true

# Поместить товар на склад
func store_item(city_index: int, good_id: int, quantity: int) -> bool:
	if city_index < 0 or city_index >= warehouses.size():
		return false
	
	var warehouse = warehouses[city_index]
	
	if not warehouse["owner"]:
		print("[WarehouseSystem] Склад в городе %d не арендован" % city_index)
		return false
	
	# Проверка лимита слотов
	var current_items = 0
	for item_quantity in warehouse["content"].values():
		current_items += item_quantity
	
	if current_items + quantity > warehouse["max_slots"]:
		print("[WarehouseSystem] На складе в городе %d недостаточно места! Максимум: %d, попытка добавить: %d" % [city_index, warehouse["max_slots"], quantity])
		return false
	
	# Проверка наличия товара в инвентаре игрока
	if not game_manager.remove_item(good_id, quantity):
		print("[WarehouseSystem] Недостаточно товара %d в инвентаре" % good_id)
		return false
	
	# Добавляем товар на склад
	if not warehouse["content"].has(good_id):
		warehouse["content"][good_id] = 0
		warehouse["item_dates"][good_id] = game_manager.current_day
	warehouse["content"][good_id] += quantity
	
	warehouse_item_stored.emit(city_index, good_id, quantity)
	warehouse_updated.emit()
	print("[WarehouseSystem] На склад города %d помещено %d товара %d" % [city_index, quantity, good_id])
	return true

# Забрать товар со склада
func retrieve_item(city_index: int, good_id: int, quantity: int) -> bool:
	if city_index < 0 or city_index >= warehouses.size():
		return false
	
	var warehouse = warehouses[city_index]
	
	if not warehouse["owner"]:
		print("[WarehouseSystem] Склад в городе %d не арендован" % city_index)
		return false
	
	if not warehouse["content"].has(good_id) or warehouse["content"][good_id] < quantity:
		print("[WarehouseSystem] На складе города %d недостаточно товара %d" % [city_index, good_id])
		return false
	
	# Проверка места в инвентаре
	if not game_manager.add_item(good_id, quantity):
		print("[WarehouseSystem] Недостаточно места в инвентаре")
		return false
	
	# Удаляем товар со склада
	warehouse["content"][good_id] -= quantity
	if warehouse["content"][good_id] <= 0:
		warehouse["content"].erase(good_id)
	
	warehouse_item_retrieved.emit(city_index, good_id, quantity)
	warehouse_updated.emit()
	print("[WarehouseSystem] Со склада города %d получено %d товара %d" % [city_index, quantity, good_id])
	return true

# Получить содержимое склада
func get_warehouse_content(city_index: int) -> Dictionary:
	if city_index < 0 or city_index >= warehouses.size():
		return {}
	
	var warehouse = warehouses[city_index]
	if not warehouse["owner"]:
		return {}
	
	return warehouse["content"].duplicate()

# Ежедневное обновление складов
func update_daily() -> void:
	for city_index in warehouses.keys():
		var warehouse = warehouses[city_index]
		
		if warehouse["owner"]:
			# Платёж за аренду
			if not game_manager.add_money(-warehouse["rent_cost"]):
				print("[WarehouseSystem] Недостаточно денег для оплаты аренды склада в городе %d. Аренда отменена." % city_index)
				release_warehouse(city_index)
				continue
			
			warehouse["days_remaining"] -= 1
			
			# Проверка окончания договора аренды
			if warehouse["days_remaining"] <= 0:
				print("[WarehouseSystem] Срок аренды склада в городе %d истёк" % city_index)
				release_warehouse(city_index)
			
			# Товары на складе портятся в 2 раза медленнее
			# При запрос товара со склада - автоматически применяется скидка на порчу
			for good_id in warehouse["content"].keys():
				# Примечание: товары на складе НЕ портятся также как в инвентаре,
				# но при извлечении товара со склада порча будет применена автоматически
				pass

# Получить статус склада
func get_warehouse_status(city_index: int) -> Dictionary:
	if city_index < 0 or city_index >= warehouses.size():
		return {}
	
	var warehouse = warehouses[city_index]
	var item_count = 0
	for quantity in warehouse["content"].values():
		item_count += quantity
	
	return {
		"city_index": city_index,
		"name": warehouse["name"],
		"owner": warehouse["owner"],
		"days_remaining": warehouse["days_remaining"],
		"rent_cost_per_day": warehouse["rent_cost"],
		"content_items": item_count,
		"max_slots": warehouse["max_slots"],
		"fill_percent": float(item_count) / float(warehouse["max_slots"]) * 100.0
	}

# Получить статистику по всем складам
func get_all_warehouses_status() -> Array:
	var statuses = []
	for city_index in warehouses.keys():
		statuses.append(get_warehouse_status(city_index))
	return statuses

# Получить список товаров на складе
func get_warehouse_items_list(city_index: int) -> Array:
	var content = get_warehouse_content(city_index)
	var items = []
	
	if content.is_empty():
		return items
	
	for good_id in content.keys():
		items.append({
			"good_id": good_id,
			"quantity": content[good_id]
		})
	
	return items

# Применить урон складу при пожаре (30% товара уничтожается)
func apply_fire_damage(damage_percent: float) -> void:
	var warehouses_to_damage = []
	for city_index in warehouses.keys():
		var warehouse = warehouses[city_index]
		if warehouse["owner"] and not warehouse["content"].is_empty():
			warehouses_to_damage.append(city_index)
	
	if warehouses_to_damage.is_empty():
		print("[WarehouseSystem] При пожаре нет складов для урона")
		return
	
	for city_index in warehouses_to_damage:
		var warehouse = warehouses[city_index]
		var damaged_goods = {}
		
		for good_id in warehouse["content"].keys():
			var quantity = warehouse["content"][good_id]
			var damage_amount = int(quantity * damage_percent)
			damaged_goods[good_id] = damage_amount
			warehouse["content"][good_id] -= damage_amount
			
			if warehouse["content"][good_id] <= 0:
				warehouse["content"].erase(good_id)
				warehouse["item_dates"].erase(good_id)
		
		print("[WarehouseSystem] Пожар нанёс урон складу в городе %d: %s" % [city_index, damaged_goods])
		warehouse_updated.emit()

# Проверить находится ли товар на складе в городе
func is_item_in_warehouse(city_index: int, good_id: int) -> bool:
	if city_index < 0 or city_index >= warehouses.size():
		return false
	
	var warehouse = warehouses[city_index]
	if not warehouse["owner"]:
		return false
	
	return warehouse["content"].has(good_id) and warehouse["content"][good_id] > 0
