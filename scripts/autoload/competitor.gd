extends Node

var competitor_name: String
var current_city_index: int = 0
var money_in_copper: int = 10000  # Стартовый капитал больше чем у игрока
var inventory: Dictionary = {}
var reputation: int = 50

signal bought_goods(good_id: int, quantity: int, city: int)
signal sold_goods(good_id: int, quantity: int, city: int)

func _init(name: String = "Конкурент"):
	competitor_name = name

# AI логика для покупки товаров (конкуренты покупают то, что дешево)
func think_about_buying(current_prices: Dictionary, all_goods: Array) -> Dictionary:
	var decision = { "buy": [], "sell": [] }
	
	# Стратегия: покупать дешёвые товары, продавать дорогие
	for good in all_goods:
		var good_id = good["id"]
		
		# Проверяем текущую цену в нашем городе
		var price_in_city = current_prices[current_city_index].get(good_id, 0)
		
		# Простая стратегия: если цена меньше среднего, покупаем
		var average_price = 0
		var price_sum = 0
		if current_prices.size() > 0:
			for city_idx in current_prices.keys():
				price_sum += current_prices[city_idx].get(good_id, 0)
			average_price = price_sum / current_prices.size()
		
		if price_in_city < average_price:
			var quantity = randi_range(1, 10)
			if money_in_copper >= price_in_city * quantity:
				decision["buy"].append({
					"good_id": good_id,
					"quantity": quantity,
					"expected_price": average_price
				})
	
	return decision

# AI логика для продажи товаров
func think_about_selling(current_prices: Dictionary) -> Dictionary:
	var decision = { "sell": [] }
	
	# Продаём товары, если цена хорошая
	for good_id in inventory.keys():
		var quantity = inventory[good_id].get("quantity", 0)
		if quantity > 0:
			var current_price = current_prices[current_city_index].get(good_id, 0)
			
			# Простая стратегия: продаём если цена выше среднего
			var average_price = 0
			var price_sum = 0
			var count = 0
			for city_idx in current_prices.keys():
				if current_prices[city_idx].has(good_id):
					price_sum += current_prices[city_idx][good_id]
					count += 1
			average_price = price_sum / count if count > 0 else 0
			
			if current_price > average_price * 1.1:  # На 10% выше среднего
				decision["sell"].append({
					"good_id": good_id,
					"quantity": mini(quantity, randi_range(1, quantity))
				})
	
	return decision

# Добавить товар в инвентарь
func add_item(good_id: int, quantity: int):
	if not inventory.has(good_id):
		inventory[good_id] = { "quantity": 0 }
	inventory[good_id]["quantity"] += quantity

# Удалить товар из инвентаря
func remove_item(good_id: int, quantity: int) -> bool:
	if not inventory.has(good_id) or inventory[good_id]["quantity"] < quantity:
		return false
	inventory[good_id]["quantity"] -= quantity
	return true

# Получить статус конкурента
func get_status() -> Dictionary:
	return {
		"name": competitor_name,
		"city": current_city_index,
		"money": money_in_copper,
		"reputation": reputation,
		"inventory_size": inventory.size(),
		"total_items": _count_items()
	}

# Обновить конкурента каждый день (вызывается из GameManager)
func update_day():
	# Конкурент случайно путешествует
	if randf() < 0.3:
		var new_city = randi() % 3  # 3 города
		if new_city != current_city_index:
			travel_to_city(new_city)
			print("[Competitor] %s путешествует в город %d" % [competitor_name, new_city])
			
			# Добавляем слух о конкуренте
			if RumorSystem:
				RumorSystem.add_competitor_rumor(competitor_name, new_city)
	
	# Конкурент торгует (AI логика)
	var current_prices = EconomyManager.current_prices
	var decision = think_about_buying(current_prices, EconomyManager.goods_data)
	
	# Конкурент покупает товары
	for buy_action in decision["buy"]:
		var good_id = buy_action["good_id"]
		var quantity = buy_action["quantity"]
		var price = EconomyManager.get_price(good_id, current_city_index)
		var total_cost = price * quantity
		
		if money_in_copper >= total_cost:
			money_in_copper -= total_cost
			add_item(good_id, quantity)
			print("[Competitor] %s купил %d товара %d за %d медяков" % [competitor_name, quantity, good_id, total_cost])

func _count_items() -> int:
	var total = 0
	for good_id in inventory.keys():
		total += inventory[good_id].get("quantity", 0)
	return total

# Путешествие в другой город
func travel_to_city(city_index: int):
	current_city_index = city_index

# Влияние на цены (если конкурент купил много, цена растёт)
func get_price_influence(good_id: int) -> float:
	if not inventory.has(good_id):
		return 1.0
	
	var quantity = inventory[good_id].get("quantity", 0)
	# Больше товара = меньше цена (спрос/предложение)
	if quantity > 50:
		return 0.9  # -10%
	elif quantity > 20:
		return 0.95  # -5%
	
	return 1.0
