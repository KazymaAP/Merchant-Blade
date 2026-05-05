extends Node
# ConfigManager - Менеджер конфигурации игры
# Загружает и предоставляет доступ к настройкам из game_config.json

var config_path: String = "res://data/game_config.json"
var config: Dictionary = {}

func _ready():
	load_config()

# Загрузить конфиг из JSON файла
func load_config() -> bool:
	var file = FileAccess.open(config_path, FileAccess.READ)
	if file == null:
		print("[ConfigManager] ОШИБКА: Конфиг файл не найден:", config_path)
		return false
	
	var json_string = file.get_as_text()
	var loaded_config = JSON.parse_string(json_string)
	
	if loaded_config == null:
		print("[ConfigManager] ОШИБКА: Не удалось распарсить конфиг")
		return false
	
	config = loaded_config
	print("[ConfigManager] Конфиг загружен успешно")
	return true

# Получить значение по пути (например, "economy.tax_rate")
func get_value(path: String, default_value = null):
	var keys = path.split(".")
	var current = config
	
	for key in keys:
		if current is Dictionary and current.has(key):
			current = current[key]
		else:
			print("[ConfigManager] ПРЕДУПРЕЖДЕНИЕ: Ключ не найден:", path)
			return default_value
	
	return current

# Получить строку значения
func get_string(path: String, default_value: String = "") -> String:
	var val = get_value(path, default_value)
	return str(val) if val != null else default_value

# Получить целое число
func get_int(path: String, default_value: int = 0) -> int:
	var val = get_value(path, default_value)
	if val is int or val is float:
		return int(val)
	return default_value

# Получить число с плавающей точкой
func get_float(path: String, default_value: float = 0.0) -> float:
	var val = get_value(path, default_value)
	if val is float or val is int:
		return float(val)
	return default_value

# Получить булево значение
func get_bool(path: String, default_value: bool = false) -> bool:
	var val = get_value(path, default_value)
	if val is bool:
		return val
	return default_value

# Получить объект (словарь)
func get_object(path: String) -> Dictionary:
	var val = get_value(path, {})
	return val if val is Dictionary else {}

# Удобные методы для часто используемых значений

func get_starting_capital() -> int:
	return get_int("game.starting_capital_copper", 5000)

func get_tax_rate() -> float:
	return get_float("economy.tax_rate", 0.05)

func get_spoilage_enabled() -> bool:
	return get_bool("spoilage.enabled", true)

func get_battle_enabled() -> bool:
	return get_bool("battle.enabled", true)

func get_battle_encounter_chance() -> int:
	return get_int("battle.encounter_chance_percent", 30)

func get_max_inventory_slots() -> int:
	return get_int("spoilage.max_inventory_slots", 50)

func get_loan_enabled() -> bool:
	return get_bool("loans.enabled", true)

func get_workshop_enabled() -> bool:
	return get_bool("workshops.enabled", true)

func get_event_enabled() -> bool:
	return get_bool("events.enabled", true)

func get_quest_enabled() -> bool:
	return get_bool("quests.enabled", true)

# Настройки сложности (новое)
var current_difficulty: String = "normal"  # easy, normal, hard
var roguelike_mode: bool = false
var best_score: int = 0  # Лучший результат в roguelike (дни)

const DIFFICULTY_SETTINGS = {
	"easy": {
		"starting_capital": 300,
		"competitors": 0,
		"tax_rate": 0.03,
		"battle_chance": 0.20,
		"workshop_price": 500
	},
	"normal": {
		"starting_capital": 150,
		"competitors": 1,
		"tax_rate": 0.05,
		"battle_chance": 0.30,
		"workshop_price": 800
	},
	"hard": {
		"starting_capital": 50,
		"competitors": 2,
		"tax_rate": 0.08,
		"battle_chance": 0.40,
		"workshop_price": 1200
	}
}

func set_difficulty(difficulty: String):
	if difficulty in DIFFICULTY_SETTINGS:
		current_difficulty = difficulty
		print("[ConfigManager] Сложность установлена: %s" % difficulty)

func get_difficulty_setting(param: String) -> int:
	if current_difficulty in DIFFICULTY_SETTINGS:
		var settings = DIFFICULTY_SETTINGS[current_difficulty]
		return settings.get(param, 0)
	return 0

func set_roguelike_mode(enabled: bool):
	roguelike_mode = enabled
	print("[ConfigManager] Roguelike режим: %s" % ("включен" if enabled else "отключен"))

func is_roguelike_mode() -> bool:
	return roguelike_mode

func set_best_score(score: int):
	if score > best_score:
		best_score = score
		print("[ConfigManager] Новый рекорд: %d дней!" % best_score)

func get_best_score() -> int:
	return best_score

func get_reputation_title_threshold(title: String) -> int:
	match title:
		"merchant":
			return get_int("reputation.title_merchant_threshold", 100)
		"trader":
			return get_int("reputation.title_trader_threshold", 250)
		"merchant_king":
			return get_int("reputation.title_merchant_king_threshold", 500)
	return 0

func get_difficulty_multiplier(setting: String, param: String) -> float:
	var difficulty = get_object("difficulty")
	if difficulty.has(setting):
		var diff_data = difficulty[setting]
		if diff_data is Dictionary and diff_data.has(param):
			return float(diff_data[param])
	return 1.0

# Проверить, включена ли фича
func is_feature_enabled(feature_name: String) -> bool:
	match feature_name:
		"spoilage":
			return get_spoilage_enabled()
		"battle":
			return get_battle_enabled()
		"loans":
			return get_loan_enabled()
		"workshops":
			return get_workshop_enabled()
		"events":
			return get_event_enabled()
		"quests":
			return get_quest_enabled()
		_:
			return false

# Вывести весь конфиг в консоль для отладки
func print_config() -> void:
	var json_string = JSON.stringify(config, "\t")
	print("[ConfigManager] Текущий конфиг:\n", json_string)
