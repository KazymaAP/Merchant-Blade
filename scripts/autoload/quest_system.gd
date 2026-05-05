extends Node

var quests: Array = []
var active_quests: Array = []
var completed_quests: Array = []

# Долгосрочные контракты на поставку
var delivery_contracts: Array = []
var contract_id_counter: int = 1

signal quest_available(quest_id: String, quest_name: String)
signal quest_accepted(quest_id: String)
signal quest_progress(quest_id: String, progress: float)
signal quest_completed(quest_id: String, reward: Dictionary)
signal quest_failed(quest_id: String)

signal contract_available(contract_id: int, good_name: String, quantity: int)
signal contract_completed(contract_id: int, reward: int)

func _ready():
	_load_quests()
	print("[QuestSystem] Загружено квестов: %d" % quests.size())

# Загрузить квесты из данных
func _load_quests():
	quests = [
		{
			"id": "deliver_grain",
			"name": "Поставка зерна",
			"description": "Доставить 50 единиц зерна в Город Б за 5 дней.",
			"type": "delivery",
			"target_city": 1,  # Город Б
			"required_goods": { 1: 50 },  # 50 единиц зерна
			"time_limit": 5,
			"reward": {
				"copper": 2000,
				"reputation": 10
			},
			"contract_giver": "Купец Иван"
		},
		{
			"id": "deliver_wine",
			"name": "Винный контракт",
			"description": "Доставить 20 единиц вина в Город В за 3 дня.",
			"type": "delivery",
			"target_city": 2,  # Город В
			"required_goods": { 5: 20 },  # 20 единиц вина
			"time_limit": 3,
			"reward": {
				"copper": 1500,
				"reputation": 5
			},
			"contract_giver": "Таверник Петр"
		},
		{
			"id": "gather_iron",
			"name": "Сбор железа",
			"description": "Купить и привезти 30 единиц железа в Город А.",
			"type": "delivery",
			"target_city": 0,  # Город А
			"required_goods": { 3: 30 },  # 30 единиц железа
			"time_limit": 7,
			"reward": {
				"copper": 2500,
				"reputation": 15
			},
			"contract_giver": "Кузнец Вася"
		}
	]

# Получить доступные квесты
func get_available_quests() -> Array:
	var available = []
	for quest in quests:
		if not _is_active_or_completed(quest["id"]):
			available.append(quest)
	return available

# Принять квест
func accept_quest(quest_id: String) -> bool:
	for quest in quests:
		if quest["id"] == quest_id:
			var active_quest = quest.duplicate(true)
			active_quest["accepted_at"] = GameManager.current_day
			active_quest["progress"] = 0.0
			active_quests.append(active_quest)
			quest_accepted.emit(quest_id)
			print("[QuestSystem] Квест '%s' принят" % quest["name"])
			return true
	return false

# Проверить прогресс квеста на основе инвентаря
func update_quest_progress():
	for quest in active_quests:
		var progress = 0.0
		
		# Проверяем, есть ли у нас нужные товары
		var all_items_collected = true
		var total_items = 0
		var total_needed = 0
		
		for good_id in quest["required_goods"].keys():
			var needed = quest["required_goods"][good_id]
			var have = GameManager.get_item_quantity(good_id)
			total_items += have
			total_needed += needed
			
			if have < needed:
				all_items_collected = false
		
		progress = float(total_items) / float(total_needed)
		progress = minf(progress, 1.0)
		quest["progress"] = progress
		quest_progress.emit(quest["id"], progress)
		
		# Если все товары собраны, проверяем местоположение
		if all_items_collected and GameManager.get_current_city() == quest["target_city"]:
			_complete_quest(quest["id"])

# Завершить квест
func _complete_quest(quest_id: String) -> bool:
	var quest_index = -1
	for i in range(active_quests.size()):
		if active_quests[i]["id"] == quest_id:
			quest_index = i
			break
	
	if quest_index == -1:
		return false
	
	var quest = active_quests[quest_index]
	
	# Удаляем товары из инвентаря
	for good_id in quest["required_goods"].keys():
		GameManager.remove_item(good_id, quest["required_goods"][good_id])
	
	# Даём награду
	var reward = quest["reward"]
	if reward.has("copper"):
		GameManager.add_money(reward["copper"])
	if reward.has("reputation"):
		GameManager.set_reputation(GameManager.reputation + reward["reputation"])
	
	# Перемещаем в завершённые
	completed_quests.append(quest)
	active_quests.remove_at(quest_index)
	
	quest_completed.emit(quest_id, reward)
	print("[QuestSystem] Квест '%s' завершён! Награда: %d медяков, репутация +%d" % [
		quest["name"], 
		reward.get("copper", 0),
		reward.get("reputation", 0)
	])
	return true

# Провалить квест (если истекло время)
func fail_quest(quest_id: String) -> bool:
	var quest_index = -1
	for i in range(active_quests.size()):
		if active_quests[i]["id"] == quest_id:
			quest_index = i
			break
	
	if quest_index == -1:
		return false
	
	var quest = active_quests[quest_index]
	active_quests.remove_at(quest_index)
	
	# Теряем репутацию
	GameManager.set_reputation(maxi(0, GameManager.reputation - 5))
	
	quest_failed.emit(quest_id)
	print("[QuestSystem] Квест '%s' провален!" % quest["name"])
	return true

# Обновить квесты по дням (проверяем дедлайны)
func update_day(current_day: int):
	var quests_to_remove = []
	
	for quest in active_quests:
		var days_passed = current_day - quest["accepted_at"]
		if days_passed >= quest["time_limit"]:
			quests_to_remove.append(quest["id"])
	
	for quest_id in quests_to_remove:
		fail_quest(quest_id)

# Проверить, активен или завершён ли квест
func _is_active_or_completed(quest_id: String) -> bool:
	for quest in active_quests:
		if quest["id"] == quest_id:
			return true
	for quest in completed_quests:
		if quest["id"] == quest_id:
			return true
	return false

# Получить активные квесты
func get_active_quests() -> Array:
	return active_quests.duplicate()

# Получить статус квестов
func get_status() -> Dictionary:
	var quest_statuses = []
	for q in active_quests:
		quest_statuses.append({
			"name": q["name"],
			"progress": q.get("progress", 0.0),
			"days_left": q["time_limit"] - (GameManager.current_day - q["accepted_at"])
		})
	
	return {
		"active": active_quests.size(),
		"completed": completed_quests.size(),
		"available": quests.size() - active_quests.size() - completed_quests.size(),
		"quests": quest_statuses
	}

# Генерировать квест для события (голод, пожар и т.д.)
func generate_event_quest(event: Dictionary) -> void:
	if event["id"] == "famine":
		var quest_id = "famine_delivery_%d" % GameManager.current_day
		var new_quest = {
			"id": quest_id,
			"name": "Помощь голодающим",
			"description": "Доставить 50 единиц зерна голодающим в город за 5 дней. Награда: 3000 медяков + репутация +30",
			"type": "delivery",
			"target_city": randi() % 3,
			"required_goods": { 1: 50 },
			"time_limit": 5,
			"reward": { "copper": 3000, "reputation": 30 },
			"contract_giver": "Голодающие жители",
			"accepted_at": GameManager.current_day,
			"progress": 0.0,
			"event_quest": true
		}
		active_quests.append(new_quest)
		quest_available.emit(quest_id, new_quest["name"])
		print("[QuestSystem] Сгенерирован квест события: %s" % new_quest["name"])
	
	elif event["id"] == "fire":
		var quest_id = "fire_recovery_%d" % GameManager.current_day
		var new_quest = {
			"id": quest_id,
			"name": "Восстановление после пожара",
			"description": "Доставить 30 единиц стройматериалов для восстановления за 4 дня. Награда: 2500 медяков + репутация +20",
			"type": "delivery",
			"target_city": randi() % 3,
			"required_goods": { 5: 30 },
			"time_limit": 4,
			"reward": { "copper": 2500, "reputation": 20 },
			"contract_giver": "Начальник стройки",
			"accepted_at": GameManager.current_day,
			"progress": 0.0,
			"event_quest": true
		}
		active_quests.append(new_quest)
		quest_available.emit(quest_id, new_quest["name"])
		print("[QuestSystem] Сгенерирован квест события: %s" % new_quest["name"])

# Пожертвовать товар при событии (получить репутацию)
func donate_to_event(event_type: String, good_id: int, quantity: int) -> bool:
	if not GameManager.remove_item(good_id, quantity):
		return false
	
	# Репутация: 1 репутация за 1 товар
	var reputation_gain = quantity
	GameManager.set_reputation(GameManager.reputation + reputation_gain)
	
	print("[QuestSystem] Пожертвовано %d товара %d при событии '%s'. Репутация +%d" % [quantity, good_id, event_type, reputation_gain])
	return true

# Обновление каждый день
func update_daily() -> void:
	update_day(GameManager.current_day)
	update_quest_progress()
	check_delivery_contracts()

# Создать долгосрочный контракт на поставку
func create_delivery_contract(good_id: int, quantity: int, months: int) -> int:
	# Максимум 2 контракта одновременно
	if delivery_contracts.size() >= 2:
		return -1
	
	var contract = {
		"id": contract_id_counter,
		"good_id": good_id,
		"good_name": EconomyManager.get_good_name(good_id),
		"quantity": quantity,
		"frequency_days": 30,
		"remaining_months": months,
		"reward_per_month": 500,
		"final_bonus": 300,
		"deadline_day": GameManager.current_day + 30,
		"created_day": GameManager.current_day,
		"months_completed": 0
	}
	
	delivery_contracts.append(contract)
	contract_id_counter += 1
	
	contract_available.emit(contract["id"], contract["good_name"], contract["quantity"])
	print("[QuestSystem] Контракт %d: поставить %d %s каждый месяц %d раз" % 
		[contract["id"], quantity, contract["good_name"], months])
	
	return contract["id"]

# Проверить контракты каждый день
func check_delivery_contracts():
	for i in range(delivery_contracts.size() - 1, -1, -1):
		var contract = delivery_contracts[i]
		
		# Проверяем срок следующей поставки
		if GameManager.current_day >= contract["deadline_day"]:
			# Проверяем, есть ли товар (инвентарь имеет структуру {good_id: {quantity: ..., ...}})
			var item_data = GameManager.inventory.get(contract["good_id"], {})
			var quantity = item_data.get("quantity", 0) if item_data else 0
			
			if quantity >= contract["quantity"]:
				# Успешная поставка
				complete_contract_month(contract["id"])
			else:
				# Не хватает товара - штраф
				fail_contract(contract["id"])

# Завершить месячный платёж контракта
func complete_contract_month(contract_id: int) -> bool:
	for contract in delivery_contracts:
		if contract["id"] == contract_id:
			# Убираем товар из инвентаря
			if not GameManager.remove_item(contract["good_id"], contract["quantity"]):
				return false
			
			# Выплачиваем награду за месяц
			GameManager.add_money(contract["reward_per_month"])
			contract["months_completed"] += 1
			contract["deadline_day"] += contract["frequency_days"]
			
			# Проверяем, завершился ли контракт
			if contract["months_completed"] >= contract["remaining_months"]:
				# Финальный бонус
				GameManager.add_money(contract["final_bonus"])
				ReputationSystem.add_reputation(20)  # Репутация за успешный контракт
				print("[QuestSystem] Контракт %d завершен! Награда +%d серебра" % 
					[contract_id, contract["final_bonus"]])
				delivery_contracts.erase(contract)
				contract_completed.emit(contract_id, contract["reward_per_month"] + contract["final_bonus"])
			else:
				print("[QuestSystem] Контракт %d: месяц %d/%d выполнен" % 
					[contract_id, contract["months_completed"], contract["remaining_months"]])
			
			return true
	
	return false

# Провалить контракт
func fail_contract(contract_id: int):
	for i in range(delivery_contracts.size() - 1, -1, -1):
		var contract = delivery_contracts[i]
		if contract["id"] == contract_id:
			# Штраф
			GameManager.add_money(-200)
			ReputationSystem.add_reputation(-15)
			
			print("[QuestSystem] Контракт %d провален! Штраф -200 серебра, репутация -15" % contract_id)
			delivery_contracts.remove_at(i)
			return
	
# Получить активные контракты
func get_active_contracts() -> Array:
	return delivery_contracts.duplicate()
