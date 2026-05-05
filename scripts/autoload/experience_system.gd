extends Node

# Система опыта - торговая и боевая прогрессия
# Торговля: скидка при покупке, точность слухов
# Бой: критический удар, снижение усталости

var trade_experience: int = 0  # Опыт торговли
var combat_experience: int = 0  # Опыт боевой

const TRADE_EXP_PER_LEVEL = 1000  # Опыт для нового уровня торговли
const COMBAT_EXP_PER_LEVEL = 500   # Опыт для нового уровня боевой

signal trade_level_up(new_level: int)
signal combat_level_up(new_level: int)

func _ready():
	pass

# Добавить опыт торговли (за каждую прибыль)
func add_trade_exp(profit: int):
	var exp_gain = max(1, profit / 10)  # 1 опыт за 10 серебра прибыли
	
	var old_level = get_trade_level()
	trade_experience += exp_gain
	var new_level = get_trade_level()
	
	if new_level > old_level:
		trade_level_up.emit(new_level)
		print("[ExperienceSystem] Уровень торговли: %d" % new_level)

# Добавить опыт боевой (за каждого убитого врага)
func add_combat_exp(kills: int):
	var exp_gain = kills * 50  # 50 опыт за убитого врага
	
	var old_level = get_combat_level()
	combat_experience += exp_gain
	var new_level = get_combat_level()
	
	if new_level > old_level:
		combat_level_up.emit(new_level)
		print("[ExperienceSystem] Уровень боевой: %d" % new_level)

# Получить уровень торговли (1-10)
func get_trade_level() -> int:
	return mini(10, 1 + (trade_experience / TRADE_EXP_PER_LEVEL))

# Получить уровень боевой (1-10)
func get_combat_level() -> int:
	return mini(10, 1 + (combat_experience / COMBAT_EXP_PER_LEVEL))

# Получить опыт до следующего уровня торговли
func get_trade_exp_to_level_up() -> int:
	var current_level = get_trade_level()
	if current_level >= 10:
		return 0
	
	var exp_needed = (current_level) * TRADE_EXP_PER_LEVEL
	return max(0, exp_needed - trade_experience)

# Получить опыт до следующего уровня боевой
func get_combat_exp_to_level_up() -> int:
	var current_level = get_combat_level()
	if current_level >= 10:
		return 0
	
	var exp_needed = (current_level) * COMBAT_EXP_PER_LEVEL
	return max(0, exp_needed - combat_experience)

# Получить скидку при покупке (0-10%)
func get_trade_skill_bonus() -> float:
	var level = get_trade_level()
	match level:
		1, 2, 3:
			return (level - 1) * 0.01  # 0%, 1%, 2%
		4, 5, 6:
			return 0.03 + (level - 4) * 0.01  # 3%, 4%, 5%
		7, 8, 9, 10:
			return 0.06 + (level - 7) * 0.01  # 6%, 7%, 8%, 9%, 10%
		_:
			return 0.0

# Получить бонусы к критическому удару (%)
func get_combat_critical_bonus() -> float:
	var level = get_combat_level()
	return (level - 1) * 0.02  # +2% крита за уровень

# Получить снижение усталости (%)
func get_combat_fatigue_reduction() -> float:
	var level = get_combat_level()
	return (level - 1) * 0.05  # -5% усталости за уровень

# Получить статус опыта для UI
func get_experience_status() -> Dictionary:
	return {
		"trade_level": get_trade_level(),
		"trade_exp": trade_experience,
		"trade_exp_to_level": get_trade_exp_to_level_up(),
		"trade_bonus": "%.1f%%" % (get_trade_skill_bonus() * 100),
		"combat_level": get_combat_level(),
		"combat_exp": combat_experience,
		"combat_exp_to_level": get_combat_exp_to_level_up(),
		"combat_critical_bonus": "%.1f%%" % (get_combat_critical_bonus() * 100),
		"combat_fatigue_reduction": "%.1f%%" % (get_combat_fatigue_reduction() * 100)
	}

# Сбросить опыт (при новой игре)
func reset_experience():
	trade_experience = 0
	combat_experience = 0
