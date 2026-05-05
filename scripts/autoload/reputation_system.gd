extends Node

const REPUTATION_TIERS = [
	{ "min": 0, "name": "Неизвестный", "title": "Странник", "price_modifier": 1.1 },
	{ "min": 20, "name": "Уважаемый", "title": "Купец", "price_modifier": 1.05 },
	{ "min": 50, "name": "Известный", "title": "Торговец", "price_modifier": 1.0 },
	{ "min": 75, "name": "Легендарный", "title": "Барон", "price_modifier": 0.95 }
]

signal reputation_changed(new_reputation: int)
signal tier_reached(tier_name: String, title: String)

# Получить текущий уровень репутации
func get_tier(reputation: int = GameManager.reputation) -> Dictionary:
	var current_tier = REPUTATION_TIERS[0]
	
	for tier in REPUTATION_TIERS:
		if reputation >= tier["min"]:
			current_tier = tier
	
	return current_tier

# Получить название титула
func get_title(reputation: int = GameManager.reputation) -> String:
	return get_tier(reputation)["title"]

# Получить модификатор цен
func get_price_modifier(reputation: int = GameManager.reputation) -> float:
	return get_tier(reputation)["price_modifier"]

# Получить текущую репутацию игрока
func get_player_reputation() -> int:
	return GameManager.reputation

# Добавить репутацию
func add_reputation(amount: int):
	var old_tier = get_tier(GameManager.reputation)
	GameManager.set_reputation(GameManager.reputation + amount)
	var new_tier = get_tier(GameManager.reputation)
	
	if old_tier["name"] != new_tier["name"]:
		tier_reached.emit(new_tier["name"], new_tier["title"])
		print("[ReputationSystem] Новый уровень! Вы теперь %s (%s)" % [new_tier["title"], new_tier["name"]])
	
	reputation_changed.emit(GameManager.reputation)

# Убрать репутацию
func remove_reputation(amount: int):
	add_reputation(-amount)

# Получить статус репутации
func get_status() -> Dictionary:
	var tier = get_tier()
	var tiers_status = []
	for t in REPUTATION_TIERS:
		tiers_status.append({
			"name": t["name"],
			"title": t["title"],
			"min_reputation": t["min"],
			"reached": GameManager.reputation >= t["min"]
		})
	
	return {
		"reputation": GameManager.reputation,
		"tier_name": tier["name"],
		"title": tier["title"],
		"price_modifier": tier["price_modifier"],
		"next_tier": _get_next_tier(),
		"tiers": tiers_status
	}

# Получить следующий уровень
func _get_next_tier() -> Dictionary:
	var current_rep = GameManager.reputation
	for tier in REPUTATION_TIERS:
		if current_rep < tier["min"]:
			return {
				"name": tier["name"],
				"title": tier["title"],
				"needed": tier["min"] - current_rep
			}
	return {}  # Максимальный уровень достигнут
