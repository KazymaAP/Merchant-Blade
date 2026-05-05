extends PanelContainer

# UI для отображения состояния тюрьмы

@onready var status_label = Label.new()
@onready var days_label = Label.new()

func _ready():
	add_child(status_label)
	add_child(days_label)
	GameManager.day_updated.connect(_on_day_updated)
	visible = false
	print("[JailPanel] Инициализирована")

func _on_day_updated(day: int):
	var jail_status = BlackMarket.get_jail_status()
	
	if jail_status["is_in_jail"]:
		visible = true
		status_label.text = "В ТЮРЬМЕ!"
		days_label.text = "Осталось дней: %d" % jail_status["days_remaining"]
	else:
		visible = false
