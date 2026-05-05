extends Node

# Система титулов для игрока
# Титулы дают бонусы и активные способности

const TITLES = [
	{
		"id": "wanderer",
		"name": "Бродячий торговец",
		"min_reputation": 0,
		"min_capital": 0,
		"description": "Неизвестный путешественник"
	},
	{
		"id": "guild_trader",
		"name": "Гильдейский разносчик",
		"min_reputation": 21,
		"min_capital": 300,
		"description": "Член торговой гильдии",
		"abilities": ["call_guard"]
	},
	{
		"id": "respected_merchant",
		"name": "Уважаемый купец",
		"min_reputation": 41,
		"min_capital": 1000,
		"description": "Известный торговец",
		"abilities": ["call_guard", "emergency_loan"]
	},
	{
		"id": "trade_baron",
		"name": "Торговый барон",
		"min_reputation": 61,
		"min_capital": 3000,
		"description": "Могущественный купец",
		"abilities": ["call_guard", "emergency_loan"]
	},
	{
		"id": "prince",
		"name": "Купеческий принц",
		"min_reputation": 81,
		"min_capital": 8000,
		"description": "Легендарный торговец",
		"abilities": ["call_guard", "emergency_loan"]
	}
]

# Уникальные титулы за достижения
var unique_titles: Array = []

signal title_changed(old_title: String, new_title: String)
signal ability_used(ability: String)

var current_title: Dictionary = TITLES[0]
var title_abilities_used: Dictionary = {}  # { ability: last_used_day }

func _ready():
	print("[TitleSystem] Инициализирована система титулов")

# Получить текущий титул
func get_current_title() -> String:
	return current_title["name"]

# Получить ID текущего титула
func get_current_title_id() -> String:
	return current_title["id"]

# Получить описание текущего титула
func get_current_title_description() -> String:
	return current_title["description"]

# Получить активные способности
func get_current_abilities() -> Array:
	return current_title.get("abilities", [])

# Проверить и обновить титул
func update_title():
	var old_title = current_title
	var reputation = GameManager.reputation
	var capital = GameManager.money_in_copper
	
	# Ищем подходящий титул (от лучшего к худшему)
	for i in range(TITLES.size() - 1, -1, -1):
		var title = TITLES[i]
		if reputation >= title["min_reputation"] and capital >= title["min_capital"]:
			if current_title["id"] != title["id"]:
				current_title = title
				title_changed.emit(old_title["name"], title["name"])
				print("[TitleSystem] Новый титул! Вы теперь: %s" % title["name"])
			return
	
	# Если ничего не подходит, присваиваем первый титул
	if current_title["id"] != TITLES[0]["id"]:
		current_title = TITLES[0]
		title_changed.emit(old_title["name"], TITLES[0]["name"])

# Использовать активную способность
func use_ability(ability_name: String) -> bool:
	var abilities = get_current_abilities()
	if ability_name not in abilities:
		return false
	
	# Проверяем, не использовалась ли способность недавно (раз в день)
	var last_used = title_abilities_used.get(ability_name, -100)
	if GameManager.current_day - last_used < 1:
		return false
	
	var success = false
	match ability_name:
		"call_guard":
			success = _use_call_guard()
		"emergency_loan":
			success = _use_emergency_loan()
	
	if success:
		title_abilities_used[ability_name] = GameManager.current_day
		ability_used.emit(ability_name)
	
	return success

# Способность: вызвать стражу (+2 солдата в бою)
func _use_call_guard() -> bool:
	if GuardSystem.hire_guard("swordsman") and GuardSystem.hire_guard("archer"):
		print("[TitleSystem] Позваны стражники")
		return true
	return false

# Способность: экстренный кредит (100000 медяков = 1000 серебра, без процентов)
func _use_emergency_loan() -> bool:
	if LoanManager.take_loan(100000):
		print("[TitleSystem] Получен экстренный кредит: 100000 медяков")
		return true
	return false

# Получить информацию о титуле
func get_title_info(title_id: String) -> Dictionary:
	for title in TITLES:
		if title["id"] == title_id:
			return title
	return {}

# Получить следующий титул
func get_next_title() -> Dictionary:
	var current_index = 0
	for i in range(TITLES.size()):
		if TITLES[i]["id"] == current_title["id"]:
			current_index = i
			break
	
	if current_index < TITLES.size() - 1:
		return TITLES[current_index + 1]
	return current_title

# Получить требования для следующего титула
func get_next_title_requirements() -> Dictionary:
	var next_title = get_next_title()
	if next_title["id"] == current_title["id"]:
		return {
			"reputation_needed": next_title["min_reputation"],
			"capital_needed": next_title["min_capital"],
			"title_name": next_title["name"]
		}
	
	var reputation_needed = max(0, next_title["min_reputation"] - GameManager.reputation)
	var capital_needed = max(0, next_title["min_capital"] - GameManager.money_in_copper)
	
	return {
		"reputation_needed": reputation_needed,
		"capital_needed": capital_needed,
		"title_name": next_title["name"]
	}

# Получить статус всех титулов
func get_all_titles_status() -> Array:
	var status = []
	var reputation = ReputationSystem.get_player_reputation()
	var capital = GameManager.money_in_copper
	
	for title in TITLES:
		var unlocked = (reputation >= title["min_reputation"] and 
					   capital >= title["min_capital"])
		status.append({
			"name": title["name"],
			"id": title["id"],
			"unlocked": unlocked,
			"min_reputation": title["min_reputation"],
			"min_capital": title["min_capital"],
			"abilities": title.get("abilities", [])
		})
	return status

# Получить модификатор налога (титулы не дают скидки на налог в новой системе)
func get_tax_modifier() -> float:
	return 1.0  # Базовый налог без модификаций
