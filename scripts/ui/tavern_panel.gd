extends PanelContainer

@onready var vbox = $VBoxContainer
var current_view = "menu"

func _ready():
	DiceGame.game_started.connect(_on_game_started)
	GameManager.money_updated.connect(_on_money_updated)
	GameManager.city_changed.connect(_on_city_changed)
	
	_show_tavern_menu()

# Показать главное меню таверны
func _show_tavern_menu():
	current_view = "menu"
	
	# Очищаем контейнер
	for child in vbox.get_children():
		child.queue_free()
	
	# Добавляем заголовок
	var title = Label.new()
	title.text = "🍺 ТАВЕРНА"
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Показываем балланс
	var balance_label = Label.new()
	balance_label.text = "Ваш баланс: %s" % GameManager.get_formatted_money()
	vbox.add_child(balance_label)
	
	# Кнопки для различных услуг
	var dice_btn = Button.new()
	dice_btn.text = "🎲 Игра в кости"
	dice_btn.pressed.connect(_on_dice_game_pressed)
	vbox.add_child(dice_btn)
	
	var guard_btn = Button.new()
	guard_btn.text = "⚔️ Нанять охрану"
	guard_btn.pressed.connect(_on_hire_guard_pressed)
	vbox.add_child(guard_btn)
	
	var loan_btn = Button.new()
	loan_btn.text = "💰 Взять кредит"
	loan_btn.pressed.connect(_on_loan_pressed)
	vbox.add_child(loan_btn)
	
	var rumors_btn = Button.new()
	rumors_btn.text = "📢 Услышать слухи"
	rumors_btn.pressed.connect(_on_rumors_pressed)
	vbox.add_child(rumors_btn)
	
	var black_market_btn = Button.new()
	black_market_btn.text = "🌑 Чёрный рынок"
	black_market_btn.pressed.connect(_on_black_market_pressed)
	vbox.add_child(black_market_btn)
	
	var scout_btn = Button.new()
	scout_btn.text = "🔍 Нанять разведчика"
	scout_btn.pressed.connect(_on_scout_pressed)
	vbox.add_child(scout_btn)
	
	var equipment_btn = Button.new()
	equipment_btn.text = "⚔️ Торговец оружием"
	equipment_btn.pressed.connect(_on_equipment_pressed)
	vbox.add_child(equipment_btn)
	
	var mercenary_btn = Button.new()
	mercenary_btn.text = "💪 Гильдия наёмников"
	mercenary_btn.pressed.connect(_on_mercenary_pressed)
	vbox.add_child(mercenary_btn)

# Показать меню найма охраны
func _show_hire_guards_menu():
	current_view = "guards"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "⚔️ НАЁМ ОХРАНЫ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var info = Label.new()
	info.text = "Охрана снижает вероятность боя на каждого охранника."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Показываем информацию о текущей охране
	var guard_status = GuardSystem.get_status()
	var guards_info = Label.new()
	guards_info.text = "Активных охранников: %d\nСнижение боя: %.1f%%\nДневные расходы: %d серебра" % [
		guard_status["active_guards"],
		guard_status["combat_reduction"] * 100,
		guard_status["daily_cost"]
	]
	vbox.add_child(guards_info)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Кнопки для найма разных типов охраны
	for guard_type in GuardSystem.GUARD_TYPES.keys():
		var guard_info = GuardSystem.GUARD_TYPES[guard_type]
		var btn = Button.new()
		btn.text = "%s - %d серебра/день" % [guard_info["name"], guard_info["cost_per_day"]]
		btn.pressed.connect(func(): _hire_guard(guard_type))
		vbox.add_child(btn)
	
	# Кнопка возврата
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

# Показать меню кредитов
func _show_loan_menu():
	current_view = "loans"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "💰 КРЕДИТЫ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var info = Label.new()
	info.text = "Возьмите кредит для развития торговли.\nПроцентная ставка: 10%% в месяц"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Показываем активные кредиты
	var active_loans = LoanManager.loans
	if active_loans.size() > 0:
		var loans_label = Label.new()
		loans_label.text = "Активные кредиты:"
		vbox.add_child(loans_label)
		
		for loan in active_loans:
			var loan_info = Label.new()
			loan_info.text = "  ID: %d | Сумма: %d медяков | Возврат: день %d" % [
				loan["id"],
				loan["amount"],
				loan["due_day"]
			]
			vbox.add_child(loan_info)
		
		var sep2 = HSeparator.new()
		vbox.add_child(sep2)
	
	# Форма для взятия нового кредита
	var hbox = HBoxContainer.new()
	var label = Label.new()
	label.text = "Размер кредита (медяки):"
	hbox.add_child(label)
	
	var input = LineEdit.new()
	input.placeholder_text = "Введите сумму"
	hbox.add_child(input)
	vbox.add_child(hbox)
	
	var btn = Button.new()
	btn.text = "Взять кредит"
	btn.pressed.connect(func(): _take_loan(int(input.text)))
	vbox.add_child(btn)
	
	# Кнопка возврата
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

# Показать слухи
func _show_rumors():
	current_view = "rumors"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "📢 СЛУХИ И НОВОСТИ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Показываем активные события
	var events = EventSystem.get_active_events()
	if events.size() > 0:
		var events_title = Label.new()
		events_title.text = "📰 События в регионе:"
		events_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(events_title)
		
		for event in events:
			var event_label = Label.new()
			event_label.text = "• %s: %s" % [event["name"], event["description"]]
			event_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(event_label)
	
	# Показываем слухи из RumorSystem
	var rumors = RumorSystem.get_active_rumors()
	if rumors.size() > 0:
		var rumors_title = Label.new()
		rumors_title.text = "\n🗣️ Слухи в городе:"
		rumors_title.add_theme_font_size_override("font_size", 16)
		vbox.add_child(rumors_title)
		
		for rumor in rumors:
			var rumor_label = Label.new()
			var false_marker = " [⚠️ подозрительно]" if rumor["is_false"] else ""
			var days_text = "день" if rumor["days_remaining"] == 1 else "дней"
			rumor_label.text = "• %s\n  (осталось: %d %s)%s" % [
				rumor["text"],
				rumor["days_remaining"],
				days_text,
				false_marker
			]
			rumor_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(rumor_label)
	else:
		var no_rumors = Label.new()
		no_rumors.text = "Слухов не слышно. Спокойные времена..."
		vbox.add_child(no_rumors)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Информация о конкуренте
	var competitor_info = Competitor.get_status()
	var comp_label = Label.new()
	comp_label.text = "\n👤 Слухи о конкуренте:\n  %s находится в городе %d\n  Его репутация: %d" % [
		competitor_info["name"],
		competitor_info["city"],
		competitor_info["reputation"]
	]
	vbox.add_child(comp_label)
	
	# Кнопка возврата
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

# Обработчики нажатий
func _on_dice_game_pressed():
	print("[Tavern] Открыть игру в кости")
	# Здесь можно добавить логику для запуска карточной игры

func _on_hire_guard_pressed():
	_show_hire_guards_menu()

func _on_loan_pressed():
	_show_loan_menu()

func _on_rumors_pressed():
	_show_rumors()

func _on_black_market_pressed():
	_show_black_market()

func _on_scout_pressed():
	_show_scout_menu()

# Показать меню найма разведчиков
func _show_scout_menu():
	current_view = "scouts"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "🔍 РАЗВЕДЧИКИ И ГОНЦЫ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var info = Label.new()
	info.text = "Разведчик: мгновенно узнает цены в других городах (50-5000 медяков)\nГонец: ежедневные отчёты о событиях в городе (333 медяков/день)"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(info)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Статус текущих разведчиков и гонцов
	var stats = ScoutSystem.get_status()
	var status_label = Label.new()
	status_label.text = "Активных разведчиков: %d\nАктивных гонцов: %d" % [stats["active_scouts"], stats["active_messengers"]]
	vbox.add_child(status_label)
	
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Кнопки для найма разведчиков по городам
	var cities = EconomyManager.cities_data
	var scout_label = Label.new()
	scout_label.text = "Нанять разведчика:"
	scout_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(scout_label)
	
	for city_idx in range(cities.size()):
		var city = cities[city_idx]
		var btn = Button.new()
		btn.text = "Разведчик в %s" % city.get("name", "Город")
		btn.pressed.connect(func(): _hire_scout(city_idx))
		vbox.add_child(btn)
	
	var separator4 = HSeparator.new()
	vbox.add_child(separator4)
	
	# Кнопки для найма гонцов по городам
	var messenger_label = Label.new()
	messenger_label.text = "Нанять гонца:"
	messenger_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(messenger_label)
	
	for city_idx in range(cities.size()):
		var city = cities[city_idx]
		var btn = Button.new()
		btn.text = "Гонец в %s" % city.get("name", "Город")
		btn.pressed.connect(func(): _hire_messenger(city_idx))
		vbox.add_child(btn)
	
	var separator5 = HSeparator.new()
	vbox.add_child(separator5)
	
	# Кнопка возврата
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

func _hire_scout(city_idx: int):
	if ScoutSystem.hire_scout(city_idx):
		_show_scout_menu()
	else:
		print("[Tavern] Ошибка при найме разведчика")

func _hire_messenger(city_idx: int):
	if ScoutSystem.hire_messenger(city_idx):
		_show_scout_menu()
	else:
		print("[Tavern] Ошибка при найме гонца")

# Показать чёрный рынок
func _show_black_market():
	if not BlackMarket.is_accessible():
		print("[Tavern] Чёрный рынок недоступен (требуется репутация 30+)")
		return
	
	current_view = "black_market"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "🌑 ЧЁРНЫЙ РЫНОК"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var warning = Label.new()
	warning.text = "⚠️ Опасно! Риск перехвата при путешествии."
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(warning)
	
	var separator2 = HSeparator.new()
	vbox.add_child(separator2)
	
	# Список контрабандных товаров
	var goods = BlackMarket.get_contraband_goods()
	for good in goods:
		var item = HBoxContainer.new()
		item.custom_minimum_size = Vector2(0, 40)
		
		var info = Label.new()
		info.text = "%s - %d м." % [good["name"], good["base_price"]]
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item.add_child(info)
		
		var buy_btn = Button.new()
		buy_btn.text = "Купить"
		buy_btn.custom_minimum_size = Vector2(80, 0)
		buy_btn.pressed.connect(func(): _buy_contraband(good["id"]))
		item.add_child(buy_btn)
		
		var sell_btn = Button.new()
		sell_btn.text = "Продать"
		sell_btn.custom_minimum_size = Vector2(80, 0)
		sell_btn.pressed.connect(func(): _sell_contraband(good["id"]))
		item.add_child(sell_btn)
		
		vbox.add_child(item)
	
	var separator3 = HSeparator.new()
	vbox.add_child(separator3)
	
	# Кнопка возврата
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

func _buy_contraband(good_id: int):
	if BlackMarket.buy_contraband(good_id, 1):
		_show_black_market()
	else:
		print("[Tavern] Ошибка при покупке контрабанды")

func _sell_contraband(good_id: int):
	if GameManager.get_item_quantity(good_id) > 0:
		var result = BlackMarket.sell_contraband(good_id, 1)
		if result["success"]:
			_show_tavern_menu()
		elif result["caught"]:
			print("[Tavern] Контрабанда перехвачена!")
			_show_tavern_menu()
	else:
		print("[Tavern] Нет товара в инвентаре")

func _hire_guard(guard_type: String):
	if GuardSystem.hire_guard(guard_type):
		_show_tavern_menu()
		print("[Tavern] Охранник нанят успешно")
	else:
		print("[Tavern] Ошибка при найме охранника")

func _take_loan(amount: int):
	if amount <= 0:
		print("[Tavern] Неверная сумма кредита")
		return
	
	if LoanManager.take_loan(amount):
		_show_loan_menu()
		print("[Tavern] Кредит взят: %d медяков" % amount)
	else:
		print("[Tavern] Ошибка при взятии кредита")

func _on_game_started(bet: int):
	_show_tavern_menu()

func _on_money_updated(copper: int):
	if current_view == "menu":
		_show_tavern_menu()

func _on_city_changed(city_index: int, city_name: String):
	_show_tavern_menu()

# Показать меню торговца оружием
func _show_equipment_shop():
	current_view = "equipment"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "⚔️ ТОРГОВЕЦ ОРУЖИЕМ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var balance_label = Label.new()
	balance_label.text = "Ваш баланс: %s" % GameManager.get_formatted_money()
	vbox.add_child(balance_label)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Показываем товары
	var shop = EquipmentSystem.get_equipment_shop(GameManager.current_city_index)
	
	var categories = {}
	for equipment in shop:
		var eq_type = equipment["type"]
		if not categories.has(eq_type):
			categories[eq_type] = []
		categories[eq_type].append(equipment)
	
	for eq_type in categories:
		var category_title = Label.new()
		match eq_type:
			"weapon":
				category_title.text = "🗡️ ОРУЖИЕ:"
			"armor":
				category_title.text = "🛡️ БРОНЯ:"
			"accessory":
				category_title.text = "💍 АКСЕССУАРЫ:"
		category_title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(category_title)
		
		for equipment in categories[eq_type]:
			var item_hbox = HBoxContainer.new()
			vbox.add_child(item_hbox)
			
			var item_label = Label.new()
			item_label.text = "%s (урон: %d, защита: %d, цена: %d)" % [
				equipment["name"],
				equipment.get("damage", 0),
				equipment.get("defense", 0),
				equipment["price"]
			]
			item_hbox.add_child(item_label)
			
			var buy_btn = Button.new()
			buy_btn.text = "Купить"
			buy_btn.pressed.connect(func(): _buy_equipment(equipment))
			item_hbox.add_child(buy_btn)
	
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

# Показать меню гильдии наёмников
func _show_mercenary_guild():
	current_view = "mercenaries"
	
	for child in vbox.get_children():
		child.queue_free()
	
	var title = Label.new()
	title.text = "💪 ГИЛЬДИЯ НАЁМНИКОВ"
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)
	
	var balance_label = Label.new()
	balance_label.text = "Ваш баланс: %s | Репутация: %d" % [
		GameManager.get_formatted_money(),
		GameManager.reputation
	]
	vbox.add_child(balance_label)
	
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	# Текущие наёмники
	var mercs = MercenaryGuild.get_mercenary_list()
	if mercs.size() > 0:
		var mercs_label = Label.new()
		mercs_label.text = "👥 ВАШИ НАЁМНИКИ:"
		mercs_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(mercs_label)
		
		for merc in mercs:
			var status = MercenaryGuild.get_mercenary_status(merc["id"])
			var merc_label = Label.new()
			var alive_str = "живой" if status["is_alive"] else "мертвый"
			merc_label.text = "%s (%s) - HP: %d/%d, Мораль: %d%%" % [
				status["name"],
				alive_str,
				status["hp"],
				status["max_hp"],
				status["morale"]
			]
			vbox.add_child(merc_label)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Доступные наёмники для найма
	var available = MercenaryGuild.get_available_mercenaries(ReputationSystem.get_player_reputation())
	if available.size() > 0:
		var available_label = Label.new()
		available_label.text = "✅ ДОСТУПНЫЕ НАЁМНИКИ:"
		available_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(available_label)
		
		for template in available:
			var btn_hbox = HBoxContainer.new()
			vbox.add_child(btn_hbox)
			
			var template_label = Label.new()
			template_label.text = "%s - HP: %d, Цена: %d серебра" % [
				template["name"],
				template["hp"],
				template["price"]
			]
			btn_hbox.add_child(template_label)
			
			var hire_btn = Button.new()
			hire_btn.text = "Нанять"
			hire_btn.pressed.connect(func(): _hire_mercenary(template["id"]))
			btn_hbox.add_child(hire_btn)
	
	var back_btn = Button.new()
	back_btn.text = "← Вернуться"
	back_btn.pressed.connect(_show_tavern_menu)
	vbox.add_child(back_btn)

func _buy_equipment(equipment: Dictionary):
	if GameManager.money_in_copper < equipment["price"]:
		_show_message("Недостаточно денег!")
		return
	
	GameManager.add_money(-equipment["price"])
	var success = EquipmentSystem.buy_equipment(0, equipment["id"], equipment["price"])
	
	if success:
		_show_message("Вы купили: %s" % equipment["name"])
		_show_equipment_shop()
	else:
		_show_message("Ошибка при покупке!")

func _hire_mercenary(template_id: String):
	var result = MercenaryGuild.hire_mercenary(template_id, ReputationSystem.get_player_reputation(), GameManager.money_in_copper)
	
	if result["success"]:
		GameManager.add_money(-result["cost"])
		_show_message("Нанят наёмник: %s" % result["mercenary"]["name"])
		_show_mercenary_guild()
	else:
		_show_message("Ошибка: %s" % result["error"])

func _show_message(message: String):
	var msg_dialog = AcceptDialog.new()
	msg_dialog.title = "Информация"
	msg_dialog.dialog_text = message
	get_tree().root.add_child(msg_dialog)
	msg_dialog.popup_centered_ratio(0.3)

func _on_equipment_pressed():
	_show_equipment_shop()

func _on_mercenary_pressed():
	_show_mercenary_guild()
