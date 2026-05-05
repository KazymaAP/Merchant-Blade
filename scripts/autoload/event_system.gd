extends Node

var events: Array = []
var active_events: Array = []
var event_history: Array = []
var warned_events: Dictionary = {}  # { event_id: true/false } - отслеживаем появление предвестника

signal event_triggered(event_name: String, description: String)
signal event_resolved(event_name: String)
signal event_warning(warning_text: String, days_until: int)

func _ready():
	_load_events()
	print("[EventSystem] Загружено событий: %d" % events.size())

# Загрузить события из JSON
func _load_events():
	events = [
		{
			"id": "famine",
			"name": "Голод",
			"description": "В регионе наступил голод! Цена на зерно растёт в 3 раза!",
			"type": "famine",
			"duration": 7,
			"affected_goods": [1],  # Зерно
			"price_modifier": 3.0,
			"rumor_warning_days": 5,
			"quest_generated": true
		},
		{
			"id": "harvest",
			"name": "Урожай",
			"description": "Богатый урожай! Цена на зерно падает на 30%.",
			"type": "harvest",
			"duration": 3,
			"affected_goods": [1],  # Зерно
			"price_modifier": 0.7
		},
		{
			"id": "fair",
			"name": "Ярмарка",
			"description": "В городе большая ярмарка! Спрос на все товары вырос.",
			"type": "fair",
			"duration": 2,
			"affected_goods": [1, 2, 3, 4, 5],
			"price_modifier": 1.3
		},
		{
			"id": "plague",
			"name": "Чума",
			"description": "Вспышка болезни! Товары портятся быстрее.",
			"type": "plague",
			"duration": 7,
			"affected_goods": [1, 2],  # Еда и товары
			"spoil_modifier": 1.5  # На 50% быстрее портится
		},
		{
			"id": "war",
			"name": "Война",
			"description": "Боевые действия! Дороги опасны, налоги растут.",
			"type": "war",
			"duration": 10,
			"tax_modifier": 1.5,
			"combat_chance_modifier": 1.5
		},
		{
			"id": "fire",
			"name": "Пожар",
			"description": "Большой пожар! Склады горят, стройматериалы в цене ×5!",
			"type": "fire",
			"duration": 5,
			"affected_goods": [5],  # Стройматериалы
			"price_modifier": 5.0,
			"warehouse_damage": 0.3,
			"rumor_warning_days": 3
		},
		{
			"id": "lords_wedding",
			"name": "Свадьба Лорда",
			"description": "Торжество! Вино, мясо и ткани в цене ×1.5, налог 0%!",
			"type": "lords_wedding",
			"duration": 3,
			"affected_goods": [2, 3, 4],  # Вино, мясо, ткани
			"price_modifier": 1.5,
			"tax_modifier": 0.0,
			"rumor_warning_days": 4
		}
	]

# Проверить и запустить события (вызывается каждый день)
func update_day(current_day: int):
	# Проверяем события, ожидающие начала (предвестники прошли)
	for event in active_events:
		if not event["is_active"] and event.has("actual_start_day") and event["actual_start_day"] == current_day:
			event["is_active"] = true
			event["days_remaining"] = event["duration"]
			event_triggered.emit(event["name"], event["description"])
			print("[EventSystem] Событие '%s' начинается сейчас!" % event["name"])
			
			# Генерируем квест, если нужен
			if event.has("quest_generated") and event["quest_generated"] and QuestSystem:
				QuestSystem.generate_event_quest(event)
			
			# Применяем урон складу при пожаре
			if event["id"] == "fire" and event.has("warehouse_damage") and WarehouseSystem:
				WarehouseSystem.apply_fire_damage(event["warehouse_damage"])
	
	# Обновляем активные события
	var expired_events = []
	for event in active_events:
		if event["is_active"]:
			event["days_remaining"] -= 1
			if event["days_remaining"] <= 0:
				expired_events.append(event)
	
	for event in expired_events:
		active_events.erase(event)
		event_resolved.emit(event["name"])
		print("[EventSystem] Событие '%s' закончилось" % event["name"])
	
	# Случайный шанс нового события (20%)
	if randf() < 0.2:
		_trigger_random_event(current_day)

# Запустить случайное событие
func _trigger_random_event(current_day: int):
	if events.is_empty():
		return
	
	var event = events[randi() % events.size()].duplicate()
	event["started_at"] = current_day
	event["days_remaining"] = event["duration"]
	event["warned"] = false
	event["is_active"] = false  # Событие пока не активно!
	
	# Генерируем предвестник (слух за N дней ДО события)
	if event.has("rumor_warning_days"):
		event["warning_day"] = current_day  # Предвестник СЕЙЧАС
		event["actual_start_day"] = current_day + event["rumor_warning_days"]  # Событие начнётся позже
		
		# Выбрасываем предвестник
		var warning_text = "Предчувствие: %s скоро произойдёт!" % event["name"]
		event_warning.emit(warning_text, event.get("rumor_warning_days", 0))
		if RumorSystem:
			RumorSystem.add_rumor(warning_text, event.get("rumor_warning_days", 0))
		event["warned"] = true
	else:
		# Если нет предвестника, событие начинается сейчас
		event["is_active"] = true
		event["actual_start_day"] = current_day
	
	active_events.append(event)
	
	if event["is_active"]:
		event_triggered.emit(event["name"], event["description"])
		print("[EventSystem] Событие '%s' началось!" % event["name"])
		
		# Генерируем квест, если нужен
		if event.has("quest_generated") and event["quest_generated"] and QuestSystem:
			QuestSystem.generate_event_quest(event)
		
		# Применяем урон складу при пожаре
		if event["id"] == "fire" and event.has("warehouse_damage") and WarehouseSystem:
			WarehouseSystem.apply_fire_damage(event["warehouse_damage"])
	else:
		print("[EventSystem] Предвестник события '%s' разослан!" % event["name"])

# Запустить конкретное событие (для тестирования)
func trigger_event(event_id: String) -> bool:
	for event in events:
		if event["id"] == event_id:
			var new_event = event.duplicate()
			new_event["started_at"] = GameManager.current_day
			new_event["days_remaining"] = event["duration"]
			new_event["is_active"] = true  # Сразу активируем для тестирования
			new_event["warned"] = true
			active_events.append(new_event)
			event_triggered.emit(event["name"], event["description"])
			
			# Генерируем квест
			if new_event.has("quest_generated") and new_event["quest_generated"] and QuestSystem:
				QuestSystem.generate_event_quest(new_event)
			
			# Применяем урон складу при пожаре
			if new_event["id"] == "fire" and new_event.has("warehouse_damage") and WarehouseSystem:
				WarehouseSystem.apply_fire_damage(new_event["warehouse_damage"])
			
			return true
	return false

# Получить активные события
func get_active_events() -> Array:
	var active = []
	for event in active_events:
		if event["is_active"]:
			active.append(event)
	return active

# Получить эффект события на цены товара
func get_price_modifier_for_good(good_id: int) -> float:
	var modifier = 1.0
	
	for event in active_events:
		if event.has("affected_goods") and good_id in event["affected_goods"]:
			if event.has("price_modifier"):
				modifier *= event["price_modifier"]
	
	return modifier

# Получить эффект события на налоги
func get_tax_modifier() -> float:
	var modifier = 1.0
	
	for event in active_events:
		if event.has("tax_modifier"):
			modifier *= event["tax_modifier"]
	
	return modifier

# Получить эффект события на шанс боя
func get_combat_chance_modifier() -> float:
	var modifier = 1.0
	
	for event in active_events:
		if event.has("combat_chance_modifier"):
			modifier *= event["combat_chance_modifier"]
	
	return modifier

# Получить статус событий
func get_status() -> Dictionary:
	var status = {
		"active_events": [],
		"total_modifiers": {
			"price": get_price_modifier_for_good(1),
			"tax": get_tax_modifier(),
			"combat": get_combat_chance_modifier()
		}
	}
	
	for event in active_events:
		status["active_events"].append({
			"name": event["name"],
			"description": event["description"],
			"days_remaining": event["days_remaining"]
		})
	
	return status

# Очистить все события (для отладки)
func clear_events():
	active_events.clear()
