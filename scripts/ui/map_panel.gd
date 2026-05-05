extends PanelContainer

@onready var message_label = $VBoxContainer/MessageLabel
@onready var buttons_container = $VBoxContainer/HBoxContainer

var city_buttons = {}

func _ready():
	GameManager.city_changed.connect(_on_city_changed)
	
	# Создаём кнопки для каждого города
	var cities = EconomyManager.get_cities_array()
	
	for city in cities:
		var btn = Button.new()
		btn.text = city["name"]
		btn.custom_minimum_size = Vector2(100, 50)
		btn.pressed.connect(_on_city_button_pressed.bindv([city["id"]]))
		buttons_container.add_child(btn)
		city_buttons[city["id"]] = btn
	
	update_message()

func _on_city_button_pressed(city_index: int):
	if city_index == GameManager.get_current_city():
		message_label.text = "Вы уже в этом городе!"
		return
	
	message_label.text = "Путешествуем в %s..." % EconomyManager.get_city_name(city_index)
	GameManager.travel_to_city(city_index)

func _on_city_changed(city_index: int, city_name: String):
	update_message()

func update_message():
	var current = GameManager.get_current_city()
	message_label.text = "Вы находитесь в: %s (День %d)" % [
		EconomyManager.get_city_name(current),
		GameManager.current_day
	]
