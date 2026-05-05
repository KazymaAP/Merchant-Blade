extends Node

# Система чёрного рынка и контрабанды

var contraband_goods: Array = []  # Товары, доступные на чёрном рынке
var game_manager: Node = null
var economy_manager: Node = null

signal contraband_sold(good_id: int, quantity: int, profit: int)
signal caught_by_guard(guard_type: String, penalty: int)

# Ссылка на уголовную репутацию
var criminal_reputation: int = 0

# Механика тюрьмы
var is_in_jail: bool = false
var jail_days_remaining: int = 0
var jail_original_city: int = -1

func _ready():
	game_manager = get_node("/root/GameManager")
	economy_manager = get_node("/root/EconomyManager")
	_initialize_contraband_goods()
	print("[BlackMarket] Система чёрного рынка инициализирована")

# Инициализировать контрабандные товары
func _initialize_contraband_goods():
	contraband_goods = [
		{
			"id": 1001,
			"name": "Краденое оружие",
			"base_price": 800,
			"risk": 0.15
		},
		{
			"id": 1002,
			"name": "Редкие меха",
			"base_price": 600,
			"risk": 0.12
		},
		{
			"id": 1003,
			"name": "Контрабандный лес",
			"base_price": 400,
			"risk": 0.10
		},
		{
			"id": 1004,
			"name": "Запрещённые лекарства",
			"base_price": 500,
			"risk": 0.15
		}
	]

# Проверить доступность чёрного рынка
func is_accessible() -> bool:
	# Доступ при репутации 30+ или специальном квесте
	if game_manager:
		return game_manager.reputation >= 30
	return false

# Получить список контрабандных товаров
func get_contraband_goods() -> Array:
	if not is_accessible():
		return []
	return contraband_goods.duplicate()

# Продать контрабанду
func sell_contraband(good_id: int, quantity: int, police_bribed: bool = false) -> Dictionary:
	var result = {
		"success": false,
		"profit": 0,
		"caught": false,
		"penalty": 0
	}
	
	if not is_accessible():
		print("[BlackMarket] Чёрный рынок недоступен")
		return result
	
	# Проверка наличия товара в инвентаре
	if game_manager.get_item_quantity(good_id) < quantity:
		print("[BlackMarket] Недостаточно товара для продажи на чёрном рынке")
		return result
	
	# Получаем товар из списка контрабанды
	var contraband_item = null
	for item in contraband_goods:
		if item["id"] == good_id:
			contraband_item = item
			break
	
	if contraband_item == null:
		print("[BlackMarket] Это не контрабандный товар")
		return result
	
	# Удаляем товар из инвентаря
	if not game_manager.remove_item(good_id, quantity):
		return result
	
	# Расчёт прибыли (без налога +20% бонуса)
	var base_profit = contraband_item["base_price"] * quantity
	var profit = int(base_profit * 1.2)  # +20% чистой прибыли
	
	# Проверка перехвата
	var risk = contraband_item["risk"]
	if police_bribed:
		risk -= 0.05  # Подкуп снижает риск на 5%
		if not game_manager.add_money(-5000):  # 50 серебра = 5000 медяков
			print("[BlackMarket] Недостаточно денег для подкупа стражи")
			return result
	
	var caught = randf() < risk
	
	if caught:
		# Игрок поймана
		result["caught"] = true
		result["penalty"] = int(profit * 0.5)  # Штраф = половина прибыли
		
		# Штраф + репутация -10 + тюрьма на 5-10 дней
		game_manager.add_money(-result["penalty"])
		game_manager.set_reputation(game_manager.reputation - 10)
		
		# Отправляем игрока в тюрьму
		_send_to_jail(randi_range(5, 10))
		
		caught_by_guard.emit("городская стража", result["penalty"])
		print("[BlackMarket] Вы были поймана! Штраф: %d медяков" % result["penalty"])
	else:
		# Успешная продажа
		result["success"] = true
		result["profit"] = profit
		game_manager.add_money(profit)
		criminal_reputation += 5
		
		contraband_sold.emit(good_id, quantity, profit)
		print("[BlackMarket] Контрабанда продана успешно! Прибыль: %d медяков" % profit)
	
	return result

# Купить контрабанду
func buy_contraband(good_id: int, quantity: int) -> bool:
	if not is_accessible():
		print("[BlackMarket] Чёрный рынок недоступен")
		return false
	
	# Получаем товар из списка контрабанды
	var contraband_item = null
	for item in contraband_goods:
		if item["id"] == good_id:
			contraband_item = item
			break
	
	if contraband_item == null:
		print("[BlackMarket] Это не контрабандный товар")
		return false
	
	var total_cost = contraband_item["base_price"] * quantity
	if not game_manager.add_money(-total_cost):
		print("[BlackMarket] Недостаточно денег для покупки контрабанды")
		return false
	
	# Добавляем товар в инвентарь
	if game_manager.add_item(good_id, quantity):
		print("[BlackMarket] Куплена контрабанда: %d ед. товара %d за %d медяков" % [quantity, good_id, total_cost])
		return true
	else:
		# Возвращаем деньги если не удалось добавить товар
		game_manager.add_money(total_cost)
		return false

# Проверка перехвата при путешествии
func check_inspection() -> bool:
	# 15% база, -5% при подкупе стражи
	var inspection_chance = 0.15
	
	# Проверка есть ли контрабанда в инвентаре
	var has_contraband = false
	for good_id in game_manager.inventory.keys():
		for contraband_item in contraband_goods:
			if contraband_item["id"] == good_id:
				has_contraband = true
				break
		if has_contraband:
			break
	
	if not has_contraband:
		return false
	
	return randf() < inspection_chance

# Отправить игрока в тюрьму
func _send_to_jail(days: int) -> void:
	if game_manager:
		jail_original_city = game_manager.current_city_index
		is_in_jail = true
		jail_days_remaining = days
		game_manager.current_city_index = 0
		print("[BlackMarket] Игрок заключен в тюрьму на %d дней (было в городе %d)" % [days, jail_original_city])

# Обновлять состояние тюрьмы каждый день
func update_jail_status() -> void:
	if not is_in_jail:
		return
	
	jail_days_remaining -= 1
	
	if jail_days_remaining <= 0:
		is_in_jail = false
		print("[BlackMarket] Игрок освобожден из тюрьмы!")
	else:
		print("[BlackMarket] В тюрьме: %d дней осталось" % jail_days_remaining)

# Получить статус тюрьмы
func get_jail_status() -> Dictionary:
	return {
		"is_in_jail": is_in_jail,
		"days_remaining": jail_days_remaining if is_in_jail else 0,
		"original_city": jail_original_city
	}

# Получить уголовную репутацию
func get_criminal_reputation() -> int:
	return criminal_reputation

# Получить статус чёрного рынка
func get_status() -> Dictionary:
	return {
		"accessible": is_accessible(),
		"criminal_reputation": criminal_reputation,
		"goods_available": contraband_goods.size() if is_accessible() else 0,
		"jail_status": get_jail_status()
	}

# Вызывается из game_manager при смене дня
func update_daily() -> void:
	update_jail_status()
