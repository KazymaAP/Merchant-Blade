extends Node

# Сигналы для обновления UI
signal money_updated(copper: int)
signal day_updated(day: int)
signal city_changed(city_index: int, city_name: String)
signal inventory_updated
signal spoilage_warning(good_id: int, days_left: int)
signal inventory_full_warning
signal reputation_updated(reputation: int)  # Сигнал для обновления репутации
signal battle_triggered(enemies: Array)  # Срабатывает когда нужно начать бой
signal battle_finished(player_won: bool, loot: Dictionary)  # Результат боя

# Основные переменные состояния
var current_city_index: int = 0  # 0=Город A, 1=Город B, 2=Город V
var money_in_copper: int = 5000  # Стартовый капитал (50 серебра)
var current_day: int = 1
var reputation: int = 50
var trade_level: int = 0
var battle_level: int = 0
var title: String = "Странник"
var total_debts: int = 0

# Roguelike состояние
var is_dead: bool = false
var roguelike_active: bool = false

# Инвентарь: { good_id: { quantity: int, spoil_day: int или null, purchase_date: int } }
var inventory: Dictionary = {}

# Боевая система
var current_battle_result: Dictionary = {}  # Результат последнего боя
var is_in_battle: bool = false

# Автозагрузка, доступна везде через GameManager.method()
func _ready():
	_apply_difficulty_settings()
	print("[GameManager] Инициализирован. Стартовый день:", current_day, ", Город:", current_city_index)

func _apply_difficulty_settings():
	# Получаем выбранную сложность
	var difficulty = ConfigManager.current_difficulty
	
	if difficulty in ConfigManager.DIFFICULTY_SETTINGS:
		var settings = ConfigManager.DIFFICULTY_SETTINGS[difficulty]
		money_in_copper = settings["starting_capital"] * 100  # Переводим в медяки
		
		print("[GameManager] Применена сложность: %s" % difficulty)
		print("  Стартовый капитал: %d" % money_in_copper)
		print("  Конкурентов: %d" % settings["competitors"])
		print("  Налог: %.0f%%" % (settings["tax_rate"] * 100))
		print("  Шанс боя: %.0f%%" % (settings["battle_chance"] * 100))
	
	# Если roguelike режим - устанавливаем флаг
	if ConfigManager.is_roguelike_mode():
		roguelike_active = true
		print("[GameManager] Режим: ROGUELIKE (Permadeath)")
	else:
		roguelike_active = false

# Добавить деньги (положительное или отрицательное значение)
func add_money(copper_amount: int) -> bool:
	if money_in_copper + copper_amount < 0:
		print("[GameManager] Недостаточно денег! Требуется:", -copper_amount, "медяков")
		return false
	money_in_copper += copper_amount
	money_updated.emit(money_in_copper)
	return true

# Получить отформатированную строку денег (золото/серебро/медь)
func get_formatted_money() -> String:
	var gold = money_in_copper / 10000
	var silver = (money_in_copper % 10000) / 100
	var copper = money_in_copper % 100
	return "%d з. %d с. %d м." % [gold, silver, copper]

# Получить количество товара в инвентаре
func get_item_quantity(good_id: int) -> int:
	if not inventory.has(good_id):
		return 0
	return inventory[good_id].get("quantity", 0)

# Добавить товар в инвентарь с указанием дня порчи (для еды)
func add_item(good_id: int, quantity: int, spoil_day: int = -1) -> bool:
	# Проверка лимита слотов инвентаря
	var current_items = 0
	for item in inventory.values():
		current_items += item.get("quantity", 0)
	
	var max_slots = ConfigManager.get_max_inventory_slots()
	if current_items + quantity > max_slots:
		print("[GameManager] ОШИБКА: Инвентарь переполнен! Максимум: %d, попытка добавить: %d" % [max_slots, current_items + quantity])
		inventory_full_warning.emit()
		return false
	
	if quantity <= 0:
		print("[GameManager] ОШИБКА: Попытка добавить отрицательное количество товара")
		return false
	
	if not inventory.has(good_id):
		inventory[good_id] = { 
			"quantity": 0,
			"purchase_date": current_day
		}
		# Устанавливаем дату порчи только при создании
		if spoil_day > 0:
			inventory[good_id]["spoil_day"] = spoil_day
	else:
		# Если товар уже есть и у новой партии дата порчи раньше, обновляем
		if spoil_day > 0:
			if not inventory[good_id].has("spoil_day") or inventory[good_id]["spoil_day"] > spoil_day:
				inventory[good_id]["spoil_day"] = spoil_day
	
	inventory[good_id]["quantity"] += quantity
	inventory_updated.emit()
	print("[GameManager] Добавлен товар %d, кол-во: +%d (всего: %d, портится в день: %s)" % [
		good_id, 
		quantity, 
		inventory[good_id]["quantity"],
		inventory[good_id].get("spoil_day", "не портится")
	])
	return true

# Удалить товар из инвентаря
func remove_item(good_id: int, quantity: int) -> bool:
	if not inventory.has(good_id) or inventory[good_id]["quantity"] < quantity:
		print("[GameManager] Недостаточно товара %d! Требуется: %d, есть: %d" % [good_id, quantity, get_item_quantity(good_id)])
		return false
	
	if quantity <= 0:
		print("[GameManager] ОШИБКА: Попытка удалить отрицательное количество товара")
		return false
	
	inventory[good_id]["quantity"] -= quantity
	if inventory[good_id]["quantity"] <= 0:
		inventory.erase(good_id)
	
	inventory_updated.emit()
	return true

# Переезд между городами (вызывается из MapPanel)
func travel_to_city(new_city_index: int):
	if new_city_index == current_city_index:
		return
	
	current_city_index = new_city_index
	current_day += 1
	
	# Обновляем события
	if EventSystem:
		EventSystem.update_day(current_day)
	
	# Обновляем компетитора
	if Competitor:
		Competitor.update_day()
	
	# Обновляем кредиты (проценты)
	if LoanManager:
		LoanManager.update_daily()
	
	# Обновляем порчу товаров
	_update_spoilage()
	
	# Уведомляем EconomyManager об обновлении дня
	EconomyManager.update_day(current_day)
	
	# Обновляем систему слухов
	if RumorSystem:
		RumorSystem.update_daily()
	
	# Обновляем систему разведчиков
	if ScoutSystem:
		ScoutSystem.update_daily()
	
	# Обновляем систему складов
	if WarehouseSystem:
		WarehouseSystem.update_daily()
	
	# Обновляем чёрный рынок и тюрьму
	if BlackMarket:
		BlackMarket.update_daily()
		if BlackMarket.check_inspection():
			print("[GameManager] Контрабанда перехвачена!")
	
	# Обновляем охрану (дневные расходы)
	if GuardSystem:
		var guard_costs = GuardSystem.update_daily()
		add_money(-guard_costs)
	
	# Обновляем наёмников (дневные расходы, мораль)
	if MercenaryGuild:
		var mercenary_costs = MercenaryGuild.update_daily_costs()
		add_money(-mercenary_costs)
	
	# Обновляем квесты
	if QuestSystem:
		QuestSystem.update_daily()
	
	# Обновляем титул (проверяем требования)
	if TitleSystem:
		TitleSystem.update_title()
	
	# Излучаем сигналы
	day_updated.emit(current_day)
	var city_name = EconomyManager.get_city_name(new_city_index)
	city_changed.emit(new_city_index, city_name)
	print("[GameManager] Прибыли в город %d (%s) в день %d" % [new_city_index, city_name, current_day])
	
	# Проверяем вероятность боя при путешествии
	_check_battle_encounter()

# Обновить порчу продовольствия при смене дня
func _update_spoilage():
	if not ConfigManager.get_spoilage_enabled():
		return
	
	var spoiled_items = []
	var warning_items = []
	
	for good_id in inventory.keys():
		var item = inventory[good_id]
		
		# Проверка: товар имеет дату порчи
		if item.has("spoil_day") and item["spoil_day"] != null:
			var days_until_spoil = item["spoil_day"] - current_day
			
			if days_until_spoil <= 0:
				# Товар портится
				spoiled_items.append(good_id)
			elif days_until_spoil <= ConfigManager.get_int("spoilage.warn_days_before_spoil", 3):
				# Предупреждение за N дней
				warning_items.append({"good_id": good_id, "days_left": days_until_spoil})
	
	# Удалить испортившиеся товары
	for good_id in spoiled_items:
		var quantity = inventory[good_id]["quantity"]
		var recovery = int(quantity * ConfigManager.get_float("spoilage.spoiled_item_recovery_percent", 0.1))
		print("[GameManager] Товар %d испортился! Потеря: %d (восстановлено: %d)" % [good_id, quantity - recovery, recovery])
		inventory.erase(good_id)
	
	# Выдать предупреждения
	for warning in warning_items:
		spoilage_warning.emit(warning["good_id"], warning["days_left"])
	
	if spoiled_items.size() > 0 or warning_items.size() > 0:
		inventory_updated.emit()

# Получить стоимость инвентаря
func get_inventory_value() -> int:
	var total_value = 0
	for good_id in inventory.keys():
		var quantity = inventory[good_id].get("quantity", 0)
		var price = EconomyManager.get_price(good_id, current_city_index)
		total_value += quantity * price
	return total_value

# Получить список товаров в инвентаре (для отображения)
func get_inventory_list() -> Array:
	var result = []
	for good_id in inventory.keys():
		result.append({
			"good_id": good_id,
			"quantity": inventory[good_id]["quantity"],
			"spoil_day": inventory[good_id].get("spoil_day", null),
			"purchase_date": inventory[good_id].get("purchase_date", current_day)
		})
	return result

# Получить текущий город
func get_current_city() -> int:
	return current_city_index

# Получить количество товаров в инвентаре
func get_total_items() -> int:
	var total = 0
	for item in inventory.values():
		total += item.get("quantity", 0)
	return total

# Получить процент заполнения инвентаря
func get_inventory_fill_percent() -> float:
	var max_slots = ConfigManager.get_max_inventory_slots()
	if max_slots <= 0:
		return 0.0
	return float(get_total_items()) / float(max_slots) * 100.0

# Установить репутацию
func set_reputation(new_reputation: int):
	reputation = clampi(new_reputation, 0, 1000)
	reputation_updated.emit(reputation)
	# Обновляем титул если нужно
	if TitleSystem:
		TitleSystem.update_title()

# Обновить титул на основе репутации
func update_title():
	if reputation >= ConfigManager.get_int("reputation.title_merchant_king_threshold", 500):
		title = "Купец-король"
	elif reputation >= ConfigManager.get_int("reputation.title_trader_threshold", 250):
		title = "Торговец"
	elif reputation >= ConfigManager.get_int("reputation.title_merchant_threshold", 100):
		title = "Купец"
	else:
		title = "Странник"

# Добавить долг
func add_debt(amount: int):
	total_debts += amount

# Игрок умер (Roguelike)
func player_died():
	if not roguelike_active:
		return  # Обычная игра не использует смерть
	
	is_dead = true
	print("[GameManager] 💀 КОНЕЦ ИГРЫ в режиме Roguelike!")
	print("[GameManager] Прожили дней: %d" % current_day)
	
	# Сохраняем результат
	ConfigManager.set_best_score(current_day)
	
	# Показываем Game Over экран
	var game_over_panel = PanelContainer.new()
	var game_over_vbox = VBoxContainer.new()
	game_over_panel.add_child(game_over_vbox)
	get_tree().root.add_child(game_over_panel)
	
	var title_label = Label.new()
	title_label.text = "💀 ИГРА ОКОНЧЕНА"
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_vbox.add_child(title_label)
	
	var stats = Label.new()
	stats.text = "Вы прожили %d дней\nЛучший результат: %d дней" % [current_day, ConfigManager.get_best_score()]
	stats.alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 18)
	game_over_vbox.add_child(stats)
	
	var menu_btn = Button.new()
	menu_btn.text = "Вернуться в меню"
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/start_screen.tscn"))
	game_over_vbox.add_child(menu_btn)

# Оплатить долг
func pay_debt(amount: int) -> bool:
	if not add_money(-amount):
		return false
	total_debts -= amount
	total_debts = max(0, total_debts)
	return true

# Получить статус инвентаря
func get_inventory_status() -> Dictionary:
	return {
		"total_items": get_total_items(),
		"max_slots": ConfigManager.get_max_inventory_slots(),
		"fill_percent": get_inventory_fill_percent(),
		"item_count": inventory.size()
	}

# Проверить вероятность боя при путешествии
func _check_battle_encounter():
	# Получаем базовую вероятность из конфига
	var battle_chance = ConfigManager.get_float("battle.encounter_chance_percent", 30.0) / 100.0
	
	# Учитываем модификатор событий (война, разбойники активны и т.д.)
	if EventSystem:
		battle_chance *= EventSystem.get_combat_chance_modifier()
	
	# Учитываем снижение от охраны
	if GuardSystem:
		battle_chance -= GuardSystem.get_combat_reduction()
	
	# Проверяем, произойдёт ли бой
	if randf() < battle_chance:
		_start_encounter()

# Начать боевой контакт
func _start_encounter():
	print("[GameManager] ⚔️ Вы столкнулись с разбойниками!")
	
	# Создаём врагов
	var enemies: Array = []
	var difficulty = 1 + (current_day / 10)  # Сложность растёт с днями
	var enemy_count = randi_range(1, 3)
	
	for i in range(enemy_count):
		var enemy_types = ["bandit", "brigand", "marauder"]
		var enemy_type = enemy_types[randi() % enemy_types.size()]
		var enemy = EnemyUnit.new(enemy_type, difficulty)
		enemies.append(enemy)
	
	is_in_battle = true
	battle_triggered.emit(enemies)

# Завершить бой с результатами
func finish_battle(player_won: bool, enemies_defeated: Array, items_lost: int = 0):
	is_in_battle = false
	
	var loot = { "copper": 0, "goods_recovered": 0 }
	
	if player_won:
		# Сбираем добычу с врагов
		for enemy in enemies_defeated:
			if enemy.has("loot"):
				for loot_key in enemy["loot"].keys():
					if loot_key == "copper":
						loot["copper"] += enemy["loot"][loot_key]
		
		# Добавляем добычу игроку
		if loot["copper"] > 0:
			add_money(loot["copper"])
			print("[GameManager] Получена добыча: %d медяков" % loot["copper"])
		
		# Добавляем опыт боя
		battle_level += 1
		print("[GameManager] Боевой опыт: +1 уровень")
		
		# Обновляем мораль охраны
		if GuardSystem:
			GuardSystem.update_morale_after_battle(true)
	else:
		# При поражении теряем товары и репутацию
		var loss_percent = ConfigManager.get_float("battle.reputation_loss_on_defeat", 10) / 100.0
		var reputation_loss = int(50 * loss_percent)
		set_reputation(reputation - reputation_loss)
		print("[GameManager] При поражении потеряна репутация: %d" % reputation_loss)
		
		# Обновляем мораль охраны
		if GuardSystem:
			GuardSystem.update_morale_after_battle(false)
		
		# Случайная потеря товаров
		if not inventory.is_empty():
			var good_ids = inventory.keys()
			var lost_good_id = good_ids[randi() % good_ids.size()]
			var quantity_lost = mini(inventory[lost_good_id]["quantity"], randi_range(5, 20))
			remove_item(lost_good_id, quantity_lost)
			loot["goods_recovered"] = quantity_lost
			print("[GameManager] Потеряно товаров: %d единиц товара %d" % [quantity_lost, lost_good_id])
	
	current_battle_result = {
		"player_won": player_won,
		"loot": loot,
		"day": current_day
	}
	
	battle_finished.emit(player_won, loot)
