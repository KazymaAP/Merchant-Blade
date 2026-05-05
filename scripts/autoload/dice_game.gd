extends Node

var player_balance: int = 0  # Ставка за текущую игру
var current_bet: int = 0
var game_history: Array = []

signal game_started(bet: int)
signal dice_rolled(player_roll: int, dealer_roll: int, player_won: bool)
signal balance_changed(new_balance: int)
signal game_ended(result: String, winnings: int)

# Начать игру с ставкой
func start_game(bet: int) -> bool:
	if bet <= 0:
		return false
	
	if GameManager.money_in_copper < bet:
		print("[DiceGame] Недостаточно денег для ставки")
		return false
	
	# Списываем ставку
	if not GameManager.add_money(-bet):
		return false
	
	current_bet = bet
	game_started.emit(bet)
	print("[DiceGame] Игра началась. Ставка: %d медяков" % bet)
	return true

# Бросить кости
func roll_dice() -> Dictionary:
	var player_roll = randi_range(1, 6) + randi_range(1, 6)  # 2-12
	var dealer_roll = randi_range(1, 6) + randi_range(1, 6)  # 2-12
	
	var player_won = player_roll > dealer_roll
	var result = ""
	var winnings = 0
	
	if player_won:
		# Выигрыш 1:1
		winnings = current_bet * 2
		GameManager.add_money(winnings)
		result = "Победа!"
	else:
		# Проигрыш (ставка уже списана)
		result = "Проигрыш..."
	
	var game_result = {
		"player_roll": player_roll,
		"dealer_roll": dealer_roll,
		"player_won": player_won,
		"result": result,
		"winnings": winnings
	}
	
	game_history.append(game_result)
	dice_rolled.emit(player_roll, dealer_roll, player_won)
	game_ended.emit(result, winnings)
	
	return game_result

# Получить историю игр
func get_history() -> Array:
	return game_history.duplicate()

# Получить статистику
func get_stats() -> Dictionary:
	var wins = 0
	var losses = 0
	var total_winnings = 0
	
	for game in game_history:
		if game["player_won"]:
			wins += 1
			total_winnings += game["winnings"]
		else:
			losses += 1
	
	return {
		"games_played": game_history.size(),
		"wins": wins,
		"losses": losses,
		"win_rate": float(wins) / float(game_history.size()) if game_history.size() > 0 else 0.0,
		"total_winnings": total_winnings
	}

# Очистить историю (для отладки)
func clear_history():
	game_history.clear()
