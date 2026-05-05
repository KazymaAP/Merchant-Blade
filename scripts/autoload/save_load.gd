extends Node

var save_path: String = "user://savegame.json"

# Сохранить состояние игры
func save_game() -> bool:
	var save_data = {
		"version": "0.2.0",
		"player": {
			"current_city_index": GameManager.current_city_index,
			"money_in_copper": GameManager.money_in_copper,
			"current_day": GameManager.current_day,
			"reputation": GameManager.reputation,
			"trade_level": GameManager.trade_level,
			"battle_level": GameManager.battle_level,
			"title": GameManager.title,
			"total_debts": GameManager.total_debts
		},
		"inventory": GameManager.inventory.duplicate(true),
		"title_system": {
			"current_title_id": TitleSystem.get_current_title_id() if TitleSystem else "stranger"
		},
		"guards": GuardSystem.current_guards.duplicate(true) if GuardSystem else [],
		"loans": LoanManager.loans.duplicate(true) if LoanManager else []
	}
	
	var json_string = JSON.stringify(save_data)
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		print("[SaveLoad] Ошибка сохранения: не удалось открыть файл")
		return false
	
	file.store_string(json_string)
	print("[SaveLoad] Игра сохранена в %s" % save_path)
	return true

# Загрузить состояние игры
func load_game() -> bool:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		print("[SaveLoad] Сохранение не найдено, используем стартовые значения")
		return false
	
	var json_string = file.get_as_text()
	var save_data = JSON.parse_string(json_string)
	
	if save_data == null:
		print("[SaveLoad] Ошибка парсинга сохранения")
		return false
	
	# Восстанавливаем состояние GameManager
	if save_data.has("player"):
		var player_data = save_data["player"]
		GameManager.current_city_index = player_data.get("current_city_index", 0)
		GameManager.money_in_copper = player_data.get("money_in_copper", ConfigManager.get_starting_capital())
		GameManager.current_day = player_data.get("current_day", 1)
		GameManager.reputation = player_data.get("reputation", 50)
		GameManager.trade_level = player_data.get("trade_level", 0)
		GameManager.battle_level = player_data.get("battle_level", 0)
		GameManager.title = player_data.get("title", "Странник")
		GameManager.total_debts = player_data.get("total_debts", 0)
	
	# Восстанавливаем инвентарь
	if save_data.has("inventory"):
		GameManager.inventory = save_data["inventory"]
	
	# Восстанавливаем титулы
	if save_data.has("title_system") and TitleSystem:
		TitleSystem.update_title()
	
	# Восстанавливаем охрану
	if save_data.has("guards") and GuardSystem:
		GuardSystem.current_guards = []
		for guard in save_data["guards"]:
			if guard["is_alive"]:
				GuardSystem.current_guards.append(guard)
	
	# Восстанавливаем кредиты
	if save_data.has("loans") and LoanManager:
		LoanManager.loans = save_data["loans"]
	
	print("[SaveLoad] Игра загружена из %s" % save_path)
	return true

# Удалить сохранение
func delete_save() -> bool:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		print("[SaveLoad] Нет сохранения для удаления")
		return false
	
	if DirAccess.remove_absolute(save_path) != OK:
		print("[SaveLoad] Ошибка удаления сохранения")
		return false
	
	print("[SaveLoad] Сохранение удалено")
	return true

# Получить информацию о сохранении
func get_save_info() -> Dictionary:
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return {}
	
	var json_string = file.get_as_text()
	var save_data = JSON.parse_string(json_string)
	
	if save_data == null or not save_data.has("player"):
		return {}
	
	var player_data = save_data["player"]
	return {
		"day": player_data.get("current_day", 1),
		"city": player_data.get("current_city_index", 0),
		"money": player_data.get("money_in_copper", 0),
		"title": player_data.get("title", "Странник"),
		"reputation": player_data.get("reputation", 0)
	}

