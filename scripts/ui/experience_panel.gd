extends PanelContainer
# UI для отображения опыта, титулов и контрактов

@onready var vbox = $VBoxContainer

func _ready():
	ExperienceSystem.trade_level_up.connect(_on_trade_level_up)
	ExperienceSystem.combat_level_up.connect(_on_combat_level_up)
	TitleSystem.title_changed.connect(_on_title_changed)
	QuestSystem.contract_available.connect(_on_contract_available)
	QuestSystem.contract_completed.connect(_on_contract_completed)
	
	GameManager.day_updated.connect(_update_display)
	_update_display(GameManager.current_day)

func _update_display(day: int):
	# Очищаем контейнер
	for child in vbox.get_children():
		child.queue_free()
	
	# Заголовок
	var title = Label.new()
	title.text = "📊 СТАТИСТИКА"
	title.add_theme_font_size_override("font_size", 18)
	vbox.add_child(title)
	
	# Система опыта
	var exp_status = ExperienceSystem.get_experience_status()
	var exp_label = Label.new()
	exp_label.text = """
🏆 ТОРГОВЛЯ: Уровень %d (%s скидка на покупку)
   Опыт: %d / нужно %d до уровня %d
⚔️ БОЕВОЙ: Уровень %d (+%s крита, -%s усталости)
   Опыт: %d / нужно %d до уровня %d
""" % [
		exp_status["trade_level"],
		exp_status["trade_bonus"],
		exp_status["trade_exp"],
		exp_status["trade_exp_to_level"],
		exp_status["trade_level"] + 1,
		exp_status["combat_level"],
		exp_status["combat_critical_bonus"],
		exp_status["combat_fatigue_reduction"],
		exp_status["combat_exp"],
		exp_status["combat_exp_to_level"],
		exp_status["combat_level"] + 1
	]
	exp_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(exp_label)
	
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)
	
	# Титул
	var title_label = Label.new()
	var current_title = TitleSystem.get_current_title()
	var current_abilities = TitleSystem.get_current_abilities()
	var abilities_str = ""
	if current_abilities.size() > 0:
		abilities_str = "\nСпособности: " + ", ".join(current_abilities)
	
	title_label.text = "👑 ТИТУЛ: %s\n%s%s" % [
		current_title,
		TitleSystem.get_current_title_description(),
		abilities_str
	]
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(title_label)
	
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)
	
	# Контракты
	var contracts = QuestSystem.get_active_contracts()
	if contracts.size() > 0:
		var contracts_label = Label.new()
		contracts_label.text = "📝 АКТИВНЫЕ КОНТРАКТЫ:"
		contracts_label.add_theme_font_size_override("font_size", 12)
		vbox.add_child(contracts_label)
		
		for contract in contracts:
			var contract_info = Label.new()
			var progress = "%d/%d" % [contract["months_completed"], contract["remaining_months"]]
			contract_info.text = "  • ID%d: %d × %s (месяц %s, срок: день %d)" % [
				contract["id"],
				contract["quantity"],
				contract["good_name"],
				progress,
				contract["deadline_day"]
			]
			vbox.add_child(contract_info)
	else:
		var no_contracts = Label.new()
		no_contracts.text = "📝 Контрактов нет. Ищите предложения в городах."
		vbox.add_child(no_contracts)

func _on_trade_level_up(new_level: int):
	print("[ExperienceUI] Уровень торговли повышен до %d!" % new_level)
	_update_display(GameManager.current_day)

func _on_combat_level_up(new_level: int):
	print("[ExperienceUI] Боевой уровень повышен до %d!" % new_level)
	_update_display(GameManager.current_day)

func _on_title_changed(old_title: String, new_title: String):
	print("[ExperienceUI] Титул изменился: %s -> %s" % [old_title, new_title])
	_update_display(GameManager.current_day)

func _on_contract_available(contract_id: int, good_name: String, quantity: int):
	print("[ExperienceUI] Доступен контракт #%d: %d × %s" % [contract_id, quantity, good_name])
	_update_display(GameManager.current_day)

func _on_contract_completed(contract_id: int, reward: int):
	print("[ExperienceUI] Контракт #%d завершен! Награда: %d серебра" % [contract_id, reward])
	_update_display(GameManager.current_day)
