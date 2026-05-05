extends PanelContainer

@onready var city_label = $VBoxContainer/CityLabel
@onready var goods_container = $VBoxContainer/ScrollContainer/VBoxContainer
@onready var money_label = $VBoxContainer/MoneyLabel
@onready var buy_quantity = $VBoxContainer/HBoxContainer/BuyQuantity
@onready var sell_quantity = $VBoxContainer/HBoxContainer/SellQuantity

var goods_list = []
var current_city = 0
var trade_offer: Dictionary = {}

func _ready():
	GameManager.city_changed.connect(_on_city_changed)
	GameManager.money_updated.connect(_on_money_updated)
	EconomyManager.price_updated.connect(_update_prices)
	
	update_trade_panel()

func update_trade_panel():
	current_city = GameManager.get_current_city()
	city_label.text = "Город: %s (День %d)" % [EconomyManager.get_city_name(current_city), GameManager.current_day]
	money_label.text = "Кошелёк: %s" % GameManager.get_formatted_money()
	
	# Очищаем старые товары
	for child in goods_container.get_children():
		child.queue_free()
	
	# Загружаем новые товары
	goods_list = EconomyManager.get_goods_for_city(current_city)
	
	for good in goods_list:
		var item = _create_good_item(good)
		goods_container.add_child(item)
	
	# Проверяем предложение бартера
	trade_offer = EconomyManager.generate_trade_offer(current_city)
	if not trade_offer.is_empty():
		var barter_item = _create_barter_item(trade_offer)
		goods_container.add_child(barter_item)

func _create_good_item(good: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 40)
	
	# Название и цены
	var info_label = Label.new()
	info_label.text = "%s | Куп: %d м. | Прод: %d м." % [
		good["name"],
		good["buy_price"],
		good["sell_price"]
	]
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(info_label)
	
	# Кнопка "Купить"
	var buy_btn = Button.new()
	buy_btn.text = "Купить"
	buy_btn.custom_minimum_size = Vector2(80, 0)
	buy_btn.pressed.connect(_on_buy_pressed.bindv([good["id"], good["buy_price"]]))
	container.add_child(buy_btn)
	
	# Кнопка "Продать"
	var sell_btn = Button.new()
	sell_btn.text = "Продать"
	sell_btn.custom_minimum_size = Vector2(80, 0)
	sell_btn.pressed.connect(_on_sell_pressed.bindv([good["id"], good["sell_price"]]))
	container.add_child(sell_btn)
	
	return container

func _create_barter_item(offer: Dictionary) -> Control:
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(0, 60)
	
	# Заголовок предложения
	var title = Label.new()
	title.text = "🔄 ПРЕДЛОЖЕНИЕ ОБМЕНА"
	title.add_theme_font_size_override("font_size", 14)
	container.add_child(title)
	
	# Описание предложения
	var desc = Label.new()
	var from_good = EconomyManager.goods_data[offer["from_good"]] if offer["from_good"] < EconomyManager.goods_data.size() else {}
	var to_good = EconomyManager.goods_data[offer["to_good"]] if offer["to_good"] < EconomyManager.goods_data.size() else {}
	desc.text = "Обменять %d %s на %d %s?" % [
		offer["from_quantity"],
		from_good.get("name", "товара"),
		offer["to_quantity"],
		to_good.get("name", "товара")
	]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	container.add_child(desc)
	
	# Кнопка принятия
	var accept_btn = Button.new()
	accept_btn.text = "Принять обмен"
	accept_btn.pressed.connect(_on_barter_accept.bindv([offer["from_good"], offer["to_good"]]))
	container.add_child(accept_btn)
	
	return container

func _on_buy_pressed(good_id: int, price: int):
	var quantity_text = buy_quantity.text if buy_quantity.text != "" else "1"
	var quantity = int(quantity_text)
	
	if quantity <= 0:
		return
	
	var total_cost = price * quantity
	if GameManager.money_in_copper < total_cost:
		print("Недостаточно денег! Требуется: %d медяков" % total_cost)
		return
	
	EconomyManager.buy_good(good_id, quantity, current_city)
	buy_quantity.text = ""
	update_trade_panel()

func _on_sell_pressed(good_id: int, price: int):
	var quantity_text = sell_quantity.text if sell_quantity.text != "" else "1"
	var quantity = int(quantity_text)
	
	if quantity <= 0:
		return
	
	EconomyManager.sell_good(good_id, quantity, current_city)
	sell_quantity.text = ""
	update_trade_panel()

func _on_barter_accept(from_good: int, to_good: int):
	if EconomyManager.accept_barter(from_good, to_good, 1):
		print("Обмен принят!")
		update_trade_panel()
	else:
		print("Обмен не удалось выполнить")

func _on_city_changed(city_index: int, city_name: String):
	update_trade_panel()

func _on_money_updated(copper: int):
	money_label.text = "Кошелёк: %s" % GameManager.get_formatted_money()

func _update_prices():
	update_trade_panel()
