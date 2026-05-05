extends Node

# Типы слухов
enum RumorType {
	FAIR,           # Ярмарка в городе
	FAMINE,         # Голод
	COMPETITOR,     # Конкурент закупает товар
	BANDITS,        # Разбойники активны
	BLACK_MARKET    # Чёрный рынок
}

# Структура слуха: { text: String, type: int, days_valid: int, is_false: bool }
var active_rumors: Array = []
var rumor_history: Array = []

signal rumor_generated(text: String, type: int, is_false: bool)
signal rumor_expired(text: String)

# Шанцы для каждого типа слуха (в процентах)
var rumor_weights: Dictionary = {
	RumorType.FAIR: 25,
	RumorType.FAMINE: 20,
	RumorType.COMPETITOR: 20,
	RumorType.BANDITS: 20,
	RumorType.BLACK_MARKET: 15
}

# Данные для генерации слухов
var cities_data: Array = []
var goods_data: Array = []

# Ссылки на менеджеры
var economy_manager: Node = null
var game_manager: Node = null

func _ready():
	economy_manager = get_node("/root/EconomyManager")
	game_manager = get_node("/root/GameManager")
	
	# Получить данные из EconomyManager
	if economy_manager:
		cities_data = economy_manager.cities_data
		goods_data = economy_manager.goods_data
	
	print("[RumorSystem] Инициализирована система слухов")

# Сгенерировать случайный слух
func generate_rumor() -> Dictionary:
	var rumor_type = _select_rumor_type()
	# Вероятность ложного слуха зависит от торгового опыта
	var false_chance = 0.15  # По умолчанию 15%
	if game_manager:
		var trade_level = game_manager.trade_level
		false_chance = max(0.02, 0.15 - (trade_level * 0.01))  # Минимум 2%, уменьшается с опытом
	var is_false = randf() < false_chance
	
	var rumor_text = _generate_rumor_text(rumor_type)
	var days_valid = randi_range(3, 7)
	
	var rumor: Dictionary = {
		"text": rumor_text,
		"type": rumor_type,
		"days_valid": days_valid,
		"days_remaining": days_valid,
		"is_false": is_false,
		"timestamp": Time.get_ticks_msec()
	}
	
	print("[RumorSystem] Сгенерирован слух: %s (ложный: %s)" % [rumor_text, is_false])
	rumor_generated.emit(rumor_text, rumor_type, is_false)
	
	return rumor

# Выбрать тип слуха по весам
func _select_rumor_type() -> int:
	var total_weight = 0
	for weight in rumor_weights.values():
		total_weight += weight
	
	var random_value = randi_range(0, total_weight - 1)
	var current = 0
	
	for type in rumor_weights.keys():
		current += rumor_weights[type]
		if random_value < current:
			return type
	
	return RumorType.FAIR

# Сгенерировать текст слуха
func _generate_rumor_text(rumor_type: int) -> String:
	if cities_data.is_empty() or goods_data.is_empty():
		return "[Ошибка генерации слуха]"
	
	var city1 = cities_data[randi() % cities_data.size()]
	var city1_name = city1.get("name", "Город")
	
	match rumor_type:
		RumorType.FAIR:
			var days = randi_range(2, 7)
			return "Говорят, в %s через %d дней большая ярмарка! Цены на роскошь вырастут." % [city1_name, days]
		
		RumorType.FAMINE:
			return "Слышно, что в %s начинается голод. Цена на зерно взлетит в небеса!" % city1_name
		
		RumorType.COMPETITOR:
			var city2 = cities_data[randi() % cities_data.size()]
			var city2_name = city2.get("name", "Город")
			var good_name = goods_data[randi() % goods_data.size()].get("name", "товар")
			return "Конкурент скупает %s в %s для продажи в %s!" % [good_name, city1_name, city2_name]
		
		RumorType.BANDITS:
			return "Разбойники активны на дороге от %s! Будьте осторожны!" % city1_name
		
		RumorType.BLACK_MARKET:
			return "На чёрном рынке %s появилось краденое оружие. Цена ниже, но риск велик!" % city1_name
	
	return "Странный слух из %s..." % city1_name

# Добавить слух вручную
func add_rumor(text: String, days_valid: int, rumor_type: int = RumorType.FAIR) -> void:
	var rumor: Dictionary = {
		"text": text,
		"type": rumor_type,
		"days_valid": days_valid,
		"days_remaining": days_valid,
		"is_false": false,
		"timestamp": Time.get_ticks_msec()
	}
	
	active_rumors.append(rumor)
	print("[RumorSystem] Добавлен слух: %s" % text)
	rumor_generated.emit(text, rumor_type, false)

# Получить все активные слухи
func get_active_rumors() -> Array:
	return active_rumors.duplicate()

# Очистить старые слухи
func clear_old_rumors() -> void:
	var expired_rumors = []
	
	for rumor in active_rumors:
		rumor["days_remaining"] -= 1
		
		if rumor["days_remaining"] <= 0:
			expired_rumors.append(rumor)
			rumor_history.append(rumor)
			rumor_expired.emit(rumor["text"])
			print("[RumorSystem] Слух истёк: %s" % rumor["text"])
	
	for rumor in expired_rumors:
		active_rumors.erase(rumor)

# Ежедневное обновление
func update_daily() -> void:
	# Очистить старые слухи
	clear_old_rumors()
	
	# 40% шанс получить новый слух в день
	if randf() < 0.4:
		var new_rumor = generate_rumor()
		active_rumors.append(new_rumor)
	
	print("[RumorSystem] Ежедневное обновление. Активных слухов: %d" % active_rumors.size())

# Добавить слух о событии
func add_event_rumor(event_name: String, event_id: String) -> void:
	var rumor_text = ""
	
	match event_id:
		"famine":
			rumor_text = "Слухи о голоде! Цены на зерно будут расти..."
		"harvest":
			rumor_text = "Говорят, богатый урожай! Зерно подешевеет..."
		"fair":
			rumor_text = "В городе готовится большая ярмарка! Товары дорожают..."
		"plague":
			rumor_text = "Ходят слухи о болезни. Товары быстрее портятся..."
		"war":
			rumor_text = "В регионе разгораются боевые действия! Опасные дороги..."
		_:
			rumor_text = "Странные новости из региона: %s" % event_name
	
	add_rumor(rumor_text, 5, RumorType.FAIR)
	print("[RumorSystem] Добавлен слух о событии: %s" % event_name)

# Добавить слух о конкуренте
func add_competitor_rumor(competitor_name: String, city_index: int) -> void:
	var city_names = ["Город A", "Город B", "Город V"]
	var city_name = city_names[city_index] if city_index < city_names.size() else "Неизвестный город"
	
	var rumor_texts = [
		"Слышно, %s видели в %s. Похоже, ищет интересные товары..." % [competitor_name, city_name],
		"%s закупает товары в %s. Может подбирается к чему-то большому..." % [competitor_name, city_name],
		"По слухам, %s сейчас в %s. Его репутация растёт..." % [competitor_name, city_name]
	]
	
	var rumor_text = rumor_texts[randi() % rumor_texts.size()]
	add_rumor(rumor_text, 3, RumorType.COMPETITOR)
	print("[RumorSystem] Добавлен слух о конкуренте: %s" % competitor_name)

# Получить статистику слухов
func get_rumor_stats() -> Dictionary:
	var false_count = 0
	for rumor in active_rumors:
		if rumor["is_false"]:
			false_count += 1
	
	return {
		"active_count": active_rumors.size(),
		"false_count": false_count,
		"history_count": rumor_history.size()
	}
