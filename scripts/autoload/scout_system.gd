extends Node

# Структура разведчика: { id: int, target_city: int, cost: int, hired_day: int, intercepted: bool, report_ready: bool, report_data: Dictionary }
var active_scouts: Array = []
var scout_history: Array = []
var scout_counter: int = 0

# Структура гонца: { id: int, target_city: int, cost_per_day: int, hired_day: int, reports: Array }
var active_messengers: Array = []
var messenger_counter: int = 0

# Ссылки на менеджеры
var game_manager: Node = null
var economy_manager: Node = null

signal scout_report_ready(scout_id: int, report: Dictionary)
signal scout_intercepted(scout_id: int, target_city: int)
signal messenger_report_received(messenger_id: int, report: Dictionary)

func _ready():
	game_manager = get_node("/root/GameManager")
	economy_manager = get_node("/root/EconomyManager")
	print("[ScoutSystem] Инициализирована система разведчиков")

# Нанять разведчика (мгновенный отчёт о ценах)
func hire_scout(target_city: int) -> bool:
	# Проверка валидности города
	if not economy_manager or target_city < 0 or target_city >= economy_manager.cities_data.size():
		print("[ScoutSystem] Ошибка: неверный номер города %d" % target_city)
		return false
	
	# Стоимость разведчика (10-50 серебра = 1000-5000 медяков)
	var cost = randi_range(1000, 5000)
	
	# Проверка денег
	if not game_manager.add_money(-cost):
		print("[ScoutSystem] Недостаточно денег для найма разведчика! Требуется: %d медяков" % cost)
		return false
	
	# Создаём разведчика
	scout_counter += 1
	var scout: Dictionary = {
		"id": scout_counter,
		"target_city": target_city,
		"cost": cost,
		"hired_day": game_manager.current_day,
		"intercepted": false,
		"report_ready": false,
		"report_data": {}
	}
	
	# Проверяем перехват (10% шанс)
	if randf() < 0.1:
		scout["intercepted"] = true
		active_scouts.append(scout)
		scout_intercepted.emit(scout["id"], target_city)
		print("[ScoutSystem] Разведчик #%d был перехвачен на пути в город %d!" % [scout["id"], target_city])
		return true
	
	# Получаем отчёт о ценах
	var report = _generate_scout_report(target_city)
	scout["report_data"] = report
	scout["report_ready"] = true
	
	active_scouts.append(scout)
	scout_report_ready.emit(scout["id"], report)
	
	var city_name = economy_manager.get_city_name(target_city)
	print("[ScoutSystem] Разведчик #%d вернулся с отчётом о ценах из города %s (стоимость: %d медяков)" % [scout["id"], city_name, cost])
	
	return true

# Получить отчёт разведчика
func get_scout_report(scout_id: int) -> Dictionary:
	for scout in active_scouts:
		if scout["id"] == scout_id and scout["report_ready"] and not scout["intercepted"]:
			return scout["report_data"].duplicate()
	
	print("[ScoutSystem] Отчёт разведчика #%d не найден" % scout_id)
	return {}

# Получить статус разведчиков
func get_status() -> Dictionary:
	return {
		"active_scouts": active_scouts.size(),
		"active_messengers": active_messengers.size()
	}

# Нанять гонца (ежедневные отчёты о событиях)
func hire_messenger(target_city: int) -> bool:
	if not economy_manager or target_city < 0 or target_city >= economy_manager.cities_data.size():
		print("[ScoutSystem] Ошибка: неверный номер города %d" % target_city)
		return false
	
	# Стоимость гонца: 100 серебра в месяц = 10000 медяков в 30 дней = 333 медяков в день
	var cost_per_day = 333
	
	# Проверка денег за первый день
	if not game_manager.add_money(-cost_per_day):
		print("[ScoutSystem] Недостаточно денег для найма гонца! Требуется: %d медяков/день" % cost_per_day)
		return false
	
	# Создаём гонца
	messenger_counter += 1
	var messenger: Dictionary = {
		"id": messenger_counter,
		"target_city": target_city,
		"cost_per_day": cost_per_day,
		"hired_day": game_manager.current_day,
		"reports": []
	}
	
	active_messengers.append(messenger)
	
	var city_name = economy_manager.get_city_name(target_city)
	print("[ScoutSystem] Гонец #%d нанят в город %s (стоимость: %d медяков/день)" % [messenger["id"], city_name, cost_per_day])
	
	return true

# Получить все активные разведчики
func get_active_scouts() -> Array:
	return active_scouts.duplicate()

# Получить все активные гонцы
func get_active_messengers() -> Array:
	return active_messengers.duplicate()

# Сгенерировать отчёт о ценах для города
func _generate_scout_report(city_index: int) -> Dictionary:
	if not economy_manager:
		return {}
	
	var prices: Dictionary = {}
	var city_name = economy_manager.get_city_name(city_index)
	
	# Получаем текущие цены в городе
	for good in economy_manager.goods_data:
		var good_id = good.get("id", 0)
		var price = economy_manager.get_price(good_id, city_index)
		prices[good_id] = {
			"name": good.get("name", "Товар"),
			"price": price
		}
	
	return {
		"city_index": city_index,
		"city_name": city_name,
		"day_received": game_manager.current_day,
		"prices": prices
	}

# Ежедневное обновление гонцов
func update_daily() -> void:
	# Обновляем платежи за гонцов
	for messenger in active_messengers:
		# Снимаем плату за день
		if not game_manager.add_money(-messenger["cost_per_day"]):
			print("[ScoutSystem] Недостаточно денег для оплаты гонца #%d. Гонец уволен." % messenger["id"])
			active_messengers.erase(messenger)
			continue
		
		# Генерируем отчёт о событиях в городе
		var report = _generate_messenger_report(messenger["target_city"])
		messenger["reports"].append(report)
		
		# Держим последние 10 отчётов
		if messenger["reports"].size() > 10:
			messenger["reports"].pop_front()
		
		messenger_report_received.emit(messenger["id"], report)
	
	# Очищаем старые разведчики (старше 5 дней)
	var expired_scouts = []
	for scout in active_scouts:
		var scout_age = game_manager.current_day - scout["hired_day"]
		if scout_age > 5:
			expired_scouts.append(scout)
	
	for scout in expired_scouts:
		active_scouts.erase(scout)
		scout_history.append(scout)

# Сгенерировать отчёт гонца о событиях в городе
func _generate_messenger_report(city_index: int) -> Dictionary:
	if not economy_manager:
		return {}
	
	var city_name = economy_manager.get_city_name(city_index)
	var events = []
	
	# Случайные события в городе (30% шанс события в день)
	if randf() < 0.3:
		var event_types = [
			"На рынке повышение спроса на продукты.",
			"Цены на ремёсла растут из-за спроса богачей.",
			"Торговцы жалуются на низкие цены.",
			"Замечен конкурент, скупающий зерно.",
			"На городской площади ярмарка!",
			"Разбойники атакуют торговцев на дорогах.",
			"В городе сообщают о болезни - спрос на лекарства растёт."
		]
		events.append(event_types[randi() % event_types.size()])
	
	return {
		"city_index": city_index,
		"city_name": city_name,
		"day": game_manager.current_day,
		"events": events
	}

# Получить статистику разведчиков
func get_scout_stats() -> Dictionary:
	var successful_scouts = 0
	var intercepted_scouts = 0
	
	for scout in active_scouts + scout_history:
		if scout["intercepted"]:
			intercepted_scouts += 1
		else:
			successful_scouts += 1
	
	return {
		"active_scouts": active_scouts.size(),
		"active_messengers": active_messengers.size(),
		"successful_reports": successful_scouts,
		"intercepted": intercepted_scouts,
		"total_cost_scouts": active_scouts.size() * 3000  # Средняя стоимость
	}
