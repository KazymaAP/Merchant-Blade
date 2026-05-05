extends PanelContainer

@onready var inventory_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var title_label = $VBoxContainer/TitleLabel

var inventory_items = []
var current_view = "inventory"  # "inventory" или "warehouse"
var current_city = 0

func _ready():
	GameManager.inventory_updated.connect(_on_inventory_updated)
	GameManager.city_changed.connect(_on_city_changed)
	if WarehouseSystem:
		WarehouseSystem.warehouse_updated.connect(_on_warehouse_updated)
	update_display()

func _on_city_changed(city_index: int, city_name: String):
	current_city = city_index
	update_display()

func update_display():
	if current_view == "inventory":
		update_inventory_display()
	else:
		update_warehouse_display()

func update_inventory_display():
	# Очищаем старые элементы
	for child in inventory_container.get_children():
		child.queue_free()
	
	inventory_items = GameManager.get_inventory_list()
	
	# Кнопка для переключения на склад
	if WarehouseSystem:
		var warehouse_status = WarehouseSystem.get_warehouse_status(current_city)
		if warehouse_status.get("owner", false):
			var switch_btn = Button.new()
			switch_btn.text = "📦 Перейти на склад"
			switch_btn.pressed.connect(func(): current_view = "warehouse"; update_display())
			inventory_container.add_child(switch_btn)
			
			var separator = HSeparator.new()
			inventory_container.add_child(separator)
	
	if inventory_items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "[Инвентарь пуст]"
		inventory_container.add_child(empty_label)
		return
	
	title_label.text = "Инвентарь (%d товаров)" % inventory_items.size()
	
	for item in inventory_items:
		var item_control = _create_inventory_item(item)
		inventory_container.add_child(item_control)

func update_warehouse_display():
	# Очищаем старые элементы
	for child in inventory_container.get_children():
		child.queue_free()
	
	if not WarehouseSystem:
		title_label.text = "Склад (не доступен)"
		return
	
	var warehouse_status = WarehouseSystem.get_warehouse_status(current_city)
	
	if not warehouse_status.get("owner", false):
		title_label.text = "Склад (не арендован)"
		var no_warehouse = Label.new()
		no_warehouse.text = "Арендуйте склад в этом городе"
		inventory_container.add_child(no_warehouse)
		return
	
	title_label.text = "Склад - %s" % warehouse_status.get("name", "Неизвестный склад")
	
	# Кнопка для переключения на инвентарь
	var switch_btn = Button.new()
	switch_btn.text = "📚 Вернуться в инвентарь"
	switch_btn.pressed.connect(func(): current_view = "inventory"; update_display())
	inventory_container.add_child(switch_btn)
	
	var separator = HSeparator.new()
	inventory_container.add_child(separator)
	
	# Информация о складе
	var info = Label.new()
	info.text = "Дней оставалось: %d\nЗанято: %.1f%% (%d/%d слотов)" % [
		warehouse_status["days_remaining"],
		warehouse_status["fill_percent"],
		warehouse_status["content_items"],
		warehouse_status["max_slots"]
	]
	inventory_container.add_child(info)
	
	var separator2 = HSeparator.new()
	inventory_container.add_child(separator2)
	
	# Список товаров на складе
	var items = WarehouseSystem.get_warehouse_items_list(current_city)
	if items.is_empty():
		var empty = Label.new()
		empty.text = "[Склад пуст]"
		inventory_container.add_child(empty)
	else:
		for item in items:
			var item_control = _create_warehouse_item(item)
			inventory_container.add_child(item_control)

func _create_inventory_item(item: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	
	var good_name = EconomyManager.get_good_name(item["good_id"])
	
	# Информация о товаре
	var info_label = Label.new()
	var text = "%s: %d ед." % [good_name, item["quantity"]]
	
	# Если товар портится, показываем день порчи
	if item.has("spoil_day") and item["spoil_day"] != null:
		var days_left = item["spoil_day"] - GameManager.current_day
		if days_left <= 0:
			text += " [ИСПОРЧЕНО]"
		else:
			text += " [портится в день %d, осталось %d дней]" % [item["spoil_day"], days_left]
	
	info_label.text = text
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(info_label)
	
	return container

func _create_warehouse_item(item: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	
	var good_name = EconomyManager.get_good_name(item["good_id"])
	
	# Информация о товаре
	var info_label = Label.new()
	info_label.text = "%s: %d ед." % [good_name, item["quantity"]]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(info_label)
	
	# Кнопка "Забрать"
	var retrieve_btn = Button.new()
	retrieve_btn.text = "Забрать"
	retrieve_btn.custom_minimum_size = Vector2(80, 0)
	retrieve_btn.pressed.connect(func(): _retrieve_from_warehouse(item["good_id"]))
	container.add_child(retrieve_btn)
	
	return container

func _retrieve_from_warehouse(good_id: int):
	if WarehouseSystem.retrieve_item(current_city, good_id, 1):
		update_display()
	else:
		print("Ошибка при изъятии товара со склада")

func _on_inventory_updated():
	if current_view == "inventory":
		update_inventory_display()

func _on_warehouse_updated():
	if current_view == "warehouse":
		update_warehouse_display()
