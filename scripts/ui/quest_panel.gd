extends PanelContainer

func _ready():
	QuestSystem.quest_accepted.connect(_on_quest_accepted)
	QuestSystem.quest_completed.connect(_on_quest_completed)
	GameManager.city_changed.connect(_on_city_changed)
	
	update_quests()

func update_quests():
	var label = $VBoxContainer/Label
	if label:
		var active = QuestSystem.get_active_quests()
		var available = QuestSystem.get_available_quests()
		label.text = "Квесты: %d активных, %d доступных" % [active.size(), available.size()]

func _on_quest_accepted(quest_id: String):
	update_quests()

func _on_quest_completed(quest_id: String, reward: Dictionary):
	update_quests()

func _on_city_changed(city_index: int, city_name: String):
	QuestSystem.update_quest_progress()
	update_quests()
