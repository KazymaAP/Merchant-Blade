extends PanelContainer

func _ready():
	ReputationSystem.reputation_changed.connect(_on_reputation_changed)
	ReputationSystem.tier_reached.connect(_on_tier_reached)
	GameManager.money_updated.connect(func(_m): update_display())
	
	update_display()

func update_display():
	# Очищаем контейнер
	for child in $VBoxContainer.get_children():
		child.queue_free()
	
	# Заголовок
	var title = Label.new()
	title.text = "👑 РЕПУТАЦИЯ И ТИТУЛЫ"
	title.add_theme_font_size_override("font_size", 20)
	$VBoxContainer.add_child(title)
	
	var separator = HSeparator.new()
	$VBoxContainer.add_child(separator)
	
	# Репутация и уровень
	var status = ReputationSystem.get_status()
	var rep_label = Label.new()
	rep_label.text = "Уровень: %s (%s)\nРепутация: %d/100" % [
		status["title"],
		status["tier_name"],
		status["reputation"]
	]
	$VBoxContainer.add_child(rep_label)
	
	# Торговый титул
	if TitleSystem:
		var sep2 = HSeparator.new()
		$VBoxContainer.add_child(sep2)
		
		var trade_title = Label.new()
		trade_title.text = "Торговый титул: %s" % TitleSystem.get_current_title()
		trade_title.add_theme_font_size_override("font_size", 16)
		$VBoxContainer.add_child(trade_title)
		
		var desc = Label.new()
		desc.text = TitleSystem.get_current_title_description()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		$VBoxContainer.add_child(desc)
		
		# Требования для следующего титула
		var next_req = TitleSystem.get_next_title_requirements()
		if next_req["reputation_needed"] > 0 or next_req["capital_needed"] > 0:
			var sep3 = HSeparator.new()
			$VBoxContainer.add_child(sep3)
			
			var next_label = Label.new()
			next_label.text = "Для %s требуется:\n  Репутация: +%d\n  Капитал: +%d медяков" % [
				next_req["title_name"],
				next_req["reputation_needed"],
				next_req["capital_needed"]
			]
			next_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			$VBoxContainer.add_child(next_label)
	
	# Модификаторы
	var sep4 = HSeparator.new()
	$VBoxContainer.add_child(sep4)
	
	var mods = Label.new()
	var tax_mod = TitleSystem.get_tax_modifier() if TitleSystem else 1.0
	mods.text = "Модификаторы:\n  Налог: %.2fx (базовый 5%%)\n  Цены: %.2fx" % [
		tax_mod,
		status.get("price_modifier", 1.0)
	]
	$VBoxContainer.add_child(mods)

func _on_reputation_changed(new_rep: int):
	update_display()

func _on_tier_reached(tier_name: String, title: String):
	update_display()
	print("🎉 Поздравляем! Вы достигли уровня %s (%s)!" % [title, tier_name])
