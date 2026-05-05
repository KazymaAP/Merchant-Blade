extends Node

signal price_updated
signal buy_completed(good_id: int, quantity: int, total_cost: int)
signal sell_completed(good_id: int, quantity: int, total_revenue: int)

# Данные товаров и городов
var goods_data: Array = []
var cities_data: Array = []

# Текущие цены: { city_index: { good_id: price_in_copper } }
var current_prices: Dictionary = {}

# Модификаторы цен (временные): { city_index: { good_id: modifier } }
# Модификатор применяется как multiplier: actual_price = base_price * modifier
var price_modifiers: Dictionary = {}

# Время, когда был применён модификатор (для отслеживания длительности)
var modifier_timestamps: Dictionary = {}

@export var goods_data_path: String = "res://data/goods.json"
@export var cities_data_path: String = "res://data/cities.json"

func _ready():
	load_data()
	initialize_prices()
	print("[EconomyManager] Инициализирован. Товаров:", goods_data.size(), ", Городов:", cities_data.size())

# Загрузить данные из JSON
func load_data():
	var goods_file = FileAccess.open(goods_data_path, FileAccess.READ)
	if goods_file == null:
		print("[EconomyManager] Ошибка: не найден", goods_data_path)
		return
	
	var goods_json = JSON.parse_string(goods_file.get_as_text())
	if goods_json is Array:
		goods_data = goods_json
	
	var cities_file = FileAccess.open(cities_data_path, FileAccess.READ)
	if cities_file == null:
		print("[EconomyManager] Ошибка: не найден", cities_data_path)
		return
	
	var cities_json = JSON.parse_string(cities_file.get_as_text())
	if cities_json is Array:
		cities_data = cities_json
	
	print("[EconomyManager] Загружены данные: %d товаров, %d городов" % [goods_data.size(), cities_data.size()])

# Инициализировать цены с небольшим случайным колебанием
func initialize_prices():
	for city_idx in range(cities_data.size()):
		current_prices[city_idx] = {}
		price_modifiers[city_idx] = {}
		modifier_timestamps[city_idx] = {}
		
		for good in goods_data:
			var base_price = good["basePrice"][city_idx]
			# Случайное колебание ±10%
			var variance = randf_range(0.9, 1.1)
			var price = int(base_price * variance)
			current_prices[city_idx][good["id"]] = price
			price_modifiers[city_idx][good["id"]] = 1.0

# Получить цену товара в городе
func get_price(good_id: int, city_index: int) -> int:
	if not current_prices.has(city_index) or not current_prices[city_index].has(good_id):
		return 0
	
	var base_price = current_prices[city_index][good_id]
	var modifier = price_modifiers[city_index].get(good_id, 1.0)
	
	# Применяем модификатор событий
	if EventSystem:
		modifier *= EventSystem.get_price_modifier_for_good(good_id)
	
	# Применяем модификатор репутации игрока
	if ReputationSystem:
		modifier *= ReputationSystem.get_price_modifier(GameManager.reputation)
	
	# Применяем влияние конкурента
	if Competitor:
		# Конкурент влияет на цены только если находится в этом же городе
		if Competitor.current_city_index == city_index:
			modifier *= Competitor.get_price_influence(good_id)
	
	return int(base_price * modifier)

# Получить информацию о товаре
func get_good_info(good_id: int) -> Dictionary:
	for good in goods_data:
		if good["id"] == good_id:
			return good
	return {}

# Получить название товара
func get_good_name(good_id: int) -> String:
	var good = get_good_info(good_id)
	return good.get("name", "Неизвестный товар")

# Получить название города
func get_city_name(city_index: int) -> String:
	if city_index >= 0 and city_index < cities_data.size():
		return cities_data[city_index].get("name", "Неизвестный город")
	return "Неизвестный город"

# Получить все товары для города
func get_goods_for_city(city_index: int) -> Array:
	var goods_list = []
	for good in goods_data:
		goods_list.append({
			"id": good["id"],
			"name": good["name"],
			"category": good["category"],
			"buy_price": get_price(good["id"], city_index),  # Цена, по которой мы покупаем ОТ торговца
			"sell_price": get_price(good["id"], city_index),  # Цена, по которой мы продаём торговцу (будет применён налог)
			"spoil_days": good.get("spoilDays", null)
		})
	return goods_list

# Купить товар
func buy_good(good_id: int, quantity: int, city_index: int) -> bool:
	var good = get_good_info(good_id)
	if good.is_empty():
		print("[EconomyManager] Товар %d не найден" % good_id)
		return false
	
	var price_per_unit = get_price(good_id, city_index)
	
	# Применяем модификатор репутации (хорошая репутация = лучшие цены)
	if ReputationSystem:
		var rep_modifier = ReputationSystem.get_price_modifier()
		price_per_unit = int(price_per_unit * rep_modifier)
	
	# Применяем бонус торговли опыта (скидка при покупке)
	if ExperienceSystem:
		var trade_bonus = ExperienceSystem.get_trade_skill_bonus()
		price_per_unit = int(price_per_unit * (1.0 - trade_bonus))
	
	var total_cost = price_per_unit * quantity
	
	# Проверка денег в GameManager
	if not GameManager.add_money(-total_cost):
		print("[EconomyManager] Недостаточно денег для покупки")
		return false
	
	# Добавляем опыт торговли (за прибыль)
	if ExperienceSystem:
		ExperienceSystem.add_trade_exp(total_cost / 5)
	
	# Определяем день порчи (если это еда)
	var spoil_day = -1
	if good.get("category") == "food":
		var spoil_days = good.get("spoilDays", 14)
		spoil_day = GameManager.current_day + spoil_days
	
	# Добавляем товар в инвентарь
	if not GameManager.add_item(good_id, quantity, spoil_day):
		# Если не удалось добавить товар, возвращаем деньги
		GameManager.add_money(total_cost)
		return false
	
	# Добавляем репутацию за покупку (чем больше - тем больше)
	if ReputationSystem:
		var rep_gain = int(quantity * 0.1)  # 10% от количества товаров
		ReputationSystem.add_reputation(rep_gain)
	
	buy_completed.emit(good_id, quantity, total_cost)
	print("[EconomyManager] Куплено %d ед. товара %d за %d медяков" % [quantity, good_id, total_cost])
	return true

# Продать товар
func sell_good(good_id: int, quantity: int, city_index: int) -> bool:
	# Проверка наличия товара в инвентаре
	if not GameManager.remove_item(good_id, quantity):
		return false
	
	# Рассчитываем доход
	var base_price = get_price(good_id, city_index)
	
	# Применяем модификатор репутации к цене продажи (хорошая репутация = лучшие цены)
	if ReputationSystem:
		var rep_modifier = ReputationSystem.get_price_modifier()
		base_price = int(base_price * rep_modifier)
	
	# Цена продажи = рыночная цена (торговец готов купить по текущей цене)
	var sell_price = base_price
	var total_revenue = sell_price * quantity
	
	# Рассчитываем налог с учётом титула
	var tax_rate = ConfigManager.get_tax_rate()
	if TitleSystem:
		tax_rate *= TitleSystem.get_tax_modifier()
	
	# Применяем модификатор налога от событий
	if EventSystem:
		tax_rate *= EventSystem.get_tax_modifier()
	
	var tax = int(total_revenue * tax_rate)
	var net_revenue = total_revenue - tax
	
	# Добавляем деньги
	GameManager.add_money(net_revenue)
	
	# Добавляем опыт торговли (за чистую прибыль)
	if ExperienceSystem:
		ExperienceSystem.add_trade_exp(net_revenue)
	
	# Применяем модификатор цены (если продали много, цена падает)
	_apply_price_modifier(good_id, city_index, quantity)
	
	# Добавляем репутацию за продажу
	if ReputationSystem:
		var rep_gain = quantity  # 1 репутация за единицу товара
		ReputationSystem.add_reputation(rep_gain)
	
	# Обновляем титул после продажи
	if TitleSystem:
		TitleSystem.update_title()
	
	# Увеличиваем уровень торговли
	GameManager.trade_level += 1
	
	sell_completed.emit(good_id, quantity, net_revenue)
	print("[EconomyManager] Продано %d ед. товара %d за %d медяков (налог: %d м., чистый доход: %d м.)" % [quantity, good_id, total_revenue, tax, net_revenue])
	return true

# Применить временный модификатор цены при большой продаже
func _apply_price_modifier(good_id: int, city_index: int, quantity: int):
	if quantity >= 10:
		# При продаже 10+ единиц цена падает на 10% на 3 дня
		if not price_modifiers[city_index].has(good_id):
			price_modifiers[city_index][good_id] = 1.0
		
		price_modifiers[city_index][good_id] *= 0.9
		modifier_timestamps[city_index][good_id] = GameManager.current_day
		print("[EconomyManager] Цена товара %d упала из-за большой продажи" % good_id)

# Обновить день (вызывается из GameManager при travel_to_city)
func update_day(new_day: int):
	# Очищаем модификаторы, чей срок истёк
	for city_idx in modifier_timestamps.keys():
		for good_id in modifier_timestamps[city_idx].keys():
			var timestamp = modifier_timestamps[city_idx][good_id]
			if new_day - timestamp >= 3:  # Модификатор длится 3 дня
				price_modifiers[city_idx][good_id] = 1.0

# СИСТЕМА БАРТЕРА ─────────────────────────────────────────────
# Текущее предложение обмена: { from_good: int, to_good: int, from_quantity: int, to_quantity: int, city: int }
var current_trade_offer: Dictionary = {}
var last_offer_day: int = -1

# Генерировать предложение обмена (НПС трейдер)
func generate_trade_offer(city_index: int) -> Dictionary:
	# 30% шанс предложения в день
	if randf() > 0.3 or GameManager.current_day == last_offer_day:
		return {}
	
	# Выбираем два случайных товара
	var good1_idx = randi() % goods_data.size()
	var good2_idx = randi() % goods_data.size()
	
	# Убеждаемся, что это разные товары
	while good2_idx == good1_idx:
		good2_idx = randi() % goods_data.size()
	
	var good1_id = goods_data[good1_idx]["id"]
	var good2_id = goods_data[good2_idx]["id"]
	
	var price1 = get_price(good1_id, city_index)
	var price2 = get_price(good2_id, city_index)
	
	# Соотношение 1:1 по рыночной цене (±20%)
	var variance = randf_range(0.8, 1.2)
	var ratio = 1.0
	if price1 > 0:
		ratio = (price2 / float(price1)) * variance
	else:
		ratio = variance
	
	var offer = {
		"from_good": good1_id,
		"to_good": good2_id,
		"from_quantity": 1,
		"to_quantity": max(1, int(ratio)),
		"city": city_index,
		"day_offered": GameManager.current_day
	}
	
	current_trade_offer = offer
	last_offer_day = GameManager.current_day
	return offer

# Получить текущее предложение обмена
func get_current_trade_offer() -> Dictionary:
	return current_trade_offer.duplicate()

# Принять предложение обмена
func accept_barter(from_good: int, to_good: int, quantity: int) -> bool:
	if current_trade_offer.is_empty():
		print("[EconomyManager] Нет активного предложения обмена")
		return false
	
	if from_good != current_trade_offer["from_good"] or to_good != current_trade_offer["to_good"]:
		print("[EconomyManager] Это предложение обмена больше недействительно")
		return false
	
	# Проверка наличия товара
	var player_quantity = GameManager.get_item_quantity(from_good)
	var required_quantity = current_trade_offer["from_quantity"] * quantity
	
	if player_quantity < required_quantity:
		print("[EconomyManager] Недостаточно товара для обмена! Требуется: %d, есть: %d" % [required_quantity, player_quantity])
		return false
	
	# Выполняем обмен
	if GameManager.remove_item(from_good, required_quantity):
		var received_quantity = current_trade_offer["to_quantity"] * quantity
		if GameManager.add_item(to_good, received_quantity):
			current_trade_offer.clear()
			print("[EconomyManager] Обмен выполнен: %d товара %d на %d товара %d" % [required_quantity, from_good, received_quantity, to_good])
			return true
		else:
			# Откатываем, если не удалось добавить товар
			GameManager.add_item(from_good, required_quantity)
			return false
	
	return false

# Ежедневное обновление цен
func update_daily():
	for city_idx in range(cities_data.size()):
		for good in goods_data:
			var good_id = good["id"]
			if modifier_timestamps[city_idx].has(good_id):
				modifier_timestamps[city_idx].erase(good_id)
	
	# Добавляем небольшое случайное колебание цен каждый день
	for city_idx in range(cities_data.size()):
		for good in goods_data:
			var good_id = good["id"]
			var base_price = good["basePrice"][city_idx]
			var variance = randf_range(0.95, 1.05)
			current_prices[city_idx][good_id] = int(base_price * variance)
	
	price_updated.emit()

# Получить все товары для UI (краткий список)
func get_goods_array() -> Array:
	return goods_data.duplicate()

# Получить все города для UI
func get_cities_array() -> Array:
	return cities_data.duplicate()
