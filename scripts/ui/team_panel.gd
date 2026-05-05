extends PanelContainer

@onready var team_label = $VBoxContainer/TeamLabel
@onready var info_container = $VBoxContainer/VBoxContainer

func _ready():
	update_team_display()
	GameManager.day_updated.connect(func(_day): update_team_display())

func update_team_display():
	# Очищаем старую информацию
	for child in info_container.get_children():
		child.queue_free()
	
	team_label.text = "Отряд"
	
	# Информация об игроке
	var player_info = Label.new()
	player_info.text = "Игрок\nHP: 100/100 (боевая система в разработке)"
	info_container.add_child(player_info)
	
	var separator = HSeparator.new()
	info_container.add_child(separator)
	
	# Информация о наёмнике
	var mercenary_info = Label.new()
	mercenary_info.text = "Наёмник: Томас\nHP: 80/80 (боевая система в разработке)"
	info_container.add_child(mercenary_info)
