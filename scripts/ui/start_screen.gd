extends Control
# Экран выбора сложности и режима

@onready var vbox = VBoxContainer.new()

func _ready():
	# Создаём главный контейнер
	var main_panel = PanelContainer.new()
	add_child(main_panel)
	main_panel.anchor_left = 0.0
	main_panel.anchor_top = 0.0
	main_panel.anchor_right = 1.0
	main_panel.anchor_bottom = 1.0
	
	# Добавляем VBox
	main_panel.add_child(vbox)
	vbox.anchor_left = 0.25
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.75
	vbox.anchor_bottom = 0.9
	
	_show_main_menu()

func _show_main_menu():
	_clear_vbox()
	
	# Заголовок
	var title = Label.new()
	title.text = "🎮 MERCHANT & BLADE"
	title.add_theme_font_size_override("font_size", 32)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Roads of Fortune"
	subtitle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(subtitle)
	
	vbox.add_child(VSeparator.new())
	
	# Обычная игра
	var normal_btn = Button.new()
	normal_btn.text = "🗺️ Обычная игра"
	normal_btn.pressed.connect(_show_difficulty_menu)
	vbox.add_child(normal_btn)
	
	# Roguelike
	var roguelike_btn = Button.new()
	roguelike_btn.text = "💀 Roguelike (Permadeath)"
	roguelike_btn.pressed.connect(func(): _start_roguelike())
	vbox.add_child(roguelike_btn)
	
	var best_score_label = Label.new()
	best_score_label.text = "🏆 Лучший результат: %d дней" % ConfigManager.get_best_score()
	best_score_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(best_score_label)

func _show_difficulty_menu():
	_clear_vbox()
	
	var title = Label.new()
	title.text = "Выберите сложность"
	title.add_theme_font_size_override("font_size", 24)
	title.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	vbox.add_child(VSeparator.new())
	
	# ЛЁГКАЯ
	var easy_panel = PanelContainer.new()
	var easy_vbox = VBoxContainer.new()
	easy_panel.add_child(easy_vbox)
	vbox.add_child(easy_panel)
	
	var easy_title = Label.new()
	easy_title.text = "⭐ ЛЁГКАЯ"
	easy_title.add_theme_font_size_override("font_size", 16)
	easy_vbox.add_child(easy_title)
	
	var easy_info = Label.new()
	easy_info.text = """
Капитал: 300 серебра
Конкурентов: 0
Налог: 3%
Шанс боя: 20%
Мастерская: 500 серебра"""
	easy_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	easy_vbox.add_child(easy_info)
	
	var easy_btn = Button.new()
	easy_btn.text = "Начать на лёгкой"
	easy_btn.pressed.connect(func(): _start_game("easy"))
	easy_vbox.add_child(easy_btn)
	
	vbox.add_child(VSeparator.new())
	
	# СРЕДНЯЯ
	var normal_panel = PanelContainer.new()
	var normal_vbox = VBoxContainer.new()
	normal_panel.add_child(normal_vbox)
	vbox.add_child(normal_panel)
	
	var normal_title = Label.new()
	normal_title.text = "⭐⭐ СРЕДНЯЯ"
	normal_title.add_theme_font_size_override("font_size", 16)
	normal_vbox.add_child(normal_title)
	
	var normal_info = Label.new()
	normal_info.text = """
Капитал: 150 серебра
Конкурентов: 1
Налог: 5%
Шанс боя: 30%
Мастерская: 800 серебра"""
	normal_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	normal_vbox.add_child(normal_info)
	
	var normal_btn = Button.new()
	normal_btn.text = "Начать на средней"
	normal_btn.pressed.connect(func(): _start_game("normal"))
	normal_vbox.add_child(normal_btn)
	
	vbox.add_child(VSeparator.new())
	
	# ТЯЖЁЛАЯ
	var hard_panel = PanelContainer.new()
	var hard_vbox = VBoxContainer.new()
	hard_panel.add_child(hard_vbox)
	vbox.add_child(hard_panel)
	
	var hard_title = Label.new()
	hard_title.text = "⭐⭐⭐ ТЯЖЁЛАЯ"
	hard_title.add_theme_font_size_override("font_size", 16)
	hard_vbox.add_child(hard_title)
	
	var hard_info = Label.new()
	hard_info.text = """
Капитал: 50 серебра
Конкурентов: 2
Налог: 8%
Шанс боя: 40%
Мастерская: 1200 серебра"""
	hard_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	hard_vbox.add_child(hard_info)
	
	var hard_btn = Button.new()
	hard_btn.text = "Начать на тяжёлой"
	hard_btn.pressed.connect(func(): _start_game("hard"))
	hard_vbox.add_child(hard_btn)
	
	vbox.add_child(VSeparator.new())
	
	# Кнопка назад
	var back_btn = Button.new()
	back_btn.text = "← Назад"
	back_btn.pressed.connect(_show_main_menu)
	vbox.add_child(back_btn)

func _start_game(difficulty: String):
	ConfigManager.set_difficulty(difficulty)
	ConfigManager.set_roguelike_mode(false)
	_load_world()

func _start_roguelike():
	ConfigManager.set_difficulty("normal")
	ConfigManager.set_roguelike_mode(true)
	_load_world()

func _load_world():
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _clear_vbox():
	for child in vbox.get_children():
		child.queue_free()
