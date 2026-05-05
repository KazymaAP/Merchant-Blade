extends Control

@onready var tab_container = $VBoxContainer/TabContainer
@onready var title_label = $VBoxContainer/TitleLabel
@onready var save_btn = $VBoxContainer/HBoxContainer/SaveButton
@onready var load_btn = $VBoxContainer/HBoxContainer/LoadButton
@onready var exit_btn = $VBoxContainer/HBoxContainer/ExitButton

func _ready():
	# Настраиваем вкладки
	tab_container.set_tab_title(0, "Торговля")
	tab_container.set_tab_title(1, "Карта")
	tab_container.set_tab_title(2, "Инвентарь")
	tab_container.set_tab_title(3, "Отряд")
	tab_container.set_tab_title(4, "Репутация")
	tab_container.set_tab_title(5, "Квесты")
	tab_container.set_tab_title(6, "Таверна")
	
	# Подключаем кнопки
	save_btn.pressed.connect(_on_save_pressed)
	load_btn.pressed.connect(_on_load_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# Обновляем заголовок
	GameManager.day_updated.connect(_on_day_updated)
	GameManager.city_changed.connect(_on_city_changed)
	update_title()

func _on_day_updated(day: int):
	update_title()

func _on_city_changed(city_index: int, city_name: String):
	update_title()

func update_title():
	title_label.text = "Merchant & Blade: Roads of Fortune | День: %d | Город: %s | Капитал: %s" % [
		GameManager.current_day,
		EconomyManager.get_city_name(GameManager.get_current_city()),
		GameManager.get_formatted_money()
	]

func _on_save_pressed():
	SaveLoad.save_game()
	print("Игра сохранена!")

func _on_load_pressed():
	SaveLoad.load_game()
	# Обновляем UI после загрузки
	GameManager.inventory_updated.emit()
	GameManager.city_changed.emit(GameManager.get_current_city(), EconomyManager.get_city_name(GameManager.get_current_city()))
	print("Игра загружена!")

func _on_exit_pressed():
	get_tree().quit()

# Заглушка для вкладок, которые ещё не реализованы
func _create_placeholder_panel(title: String) -> PanelContainer:
	var panel = PanelContainer.new()
	var label = Label.new()
	label.text = "%s\n[в разработке]" % title
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
