extends Node
class_name BattleController

enum BattleState { SETUP, PLAYER_TURN, ENEMY_TURN, FINISHED }

var battle_state: BattleState = BattleState.SETUP
var grid: BattleGrid
var current_turn: int = 0
var player_units: Array = []
var enemy_units: Array = []
var current_acting_unit: BattleUnit = null
var turn_order: Array = []  # Порядок ходов (инициатива)

signal battle_started
signal battle_ended(player_won: bool)
signal turn_changed(unit: BattleUnit, is_player: bool)
signal action_performed(action: String, result: Dictionary)
signal unit_status_changed(unit: BattleUnit)

func _ready():
	grid = BattleGrid.new()
	grid.grid_updated.connect(_on_grid_updated)

# Инициализировать бой
func start_battle(players: Array, enemies: Array):
	player_units = players
	enemy_units = enemies
	
	# Добавляем юнитов на сетку
	# Игроки слева (x = 0-1)
	var player_positions = [Vector2i(0, 1), Vector2i(0, 3)]
	for i in range(mini(player_units.size(), player_positions.size())):
		grid.add_unit(player_units[i], player_positions[i])
	
	# Враги справа (x = 3-4)
	var enemy_positions = [Vector2i(4, 1), Vector2i(4, 3)]
	for i in range(mini(enemy_units.size(), enemy_positions.size())):
		grid.add_unit(enemy_units[i], enemy_positions[i])
	
	# Расчитываем порядок ходов (инициатива)
	_calculate_turn_order()
	
	battle_state = BattleState.PLAYER_TURN
	battle_started.emit()
	_start_next_turn()

# Расчитать порядок ходов
func _calculate_turn_order():
	turn_order = []
	var all_units = player_units + enemy_units
	
	# Сортируем по инициативе (больше - лучше)
	for unit in all_units:
		turn_order.append(unit)
	
	# Просто перемешиваем для сейчас (позже можно добавить инициативу)
	turn_order.shuffle()

# Начать следующий ход
func _start_next_turn():
	if turn_order.is_empty():
		_calculate_turn_order()
	
	current_acting_unit = turn_order.pop_front()
	
	# Проверяем, жив ли юнит
	if not current_acting_unit.is_alive:
		_start_next_turn()  # Пропускаем мёртвых
		return
	
	# Определяем фазу боя
	if current_acting_unit.is_player_unit:
		battle_state = BattleState.PLAYER_TURN
	else:
		battle_state = BattleState.ENEMY_TURN
	
	turn_changed.emit(current_acting_unit, current_acting_unit.is_player_unit)
	
	# Если враг, выполняем AI
	if not current_acting_unit.is_player_unit:
		call_deferred("_perform_enemy_turn")

# Выполнить ход врага (AI)
func _perform_enemy_turn():
	var enemies = grid.get_enemies(current_acting_unit)
	
	if enemies.is_empty():
		_end_unit_turn()
		return
	
	# Найти врага в пределах атаки
	var targets = grid.get_attackable_enemies(current_acting_unit)
	
	if targets.size() > 0:
		# Атакуем первого врага в списке
		var target = targets[0]
		var result = current_acting_unit.attack(target)
		action_performed.emit("attack", result)
		unit_status_changed.emit(target)
	else:
		# Двигаемся ближе к врагу
		var closest_enemy = enemies[0]
		var closest_distance = current_acting_unit.distance_to(closest_enemy)
		
		for enemy in enemies:
			var distance = current_acting_unit.distance_to(enemy)
			if distance < closest_distance:
				closest_enemy = enemy
				closest_distance = distance
		
		# Двигаемся в сторону врага
		var moves = grid.get_available_moves(current_acting_unit)
		if moves.size() > 0:
			# Выбираем ход, ближайший к врагу
			var best_move = moves[0]
			var best_distance = current_acting_unit.distance_to(closest_enemy)
			
			for move in moves:
				var test_distance = maxi(abs(move.x - closest_enemy.position.x),
										 abs(move.y - closest_enemy.position.y))
				if test_distance < best_distance:
					best_move = move
					best_distance = test_distance
			
			grid.move_unit(current_acting_unit, best_move)
			action_performed.emit("move", { "unit": current_acting_unit.unit_name, "to": best_move })
	
	_end_unit_turn()

# Игрок выбирает действие
func perform_player_action(action: String, target: BattleUnit = null, position: Vector2i = Vector2i.ZERO) -> bool:
	if battle_state != BattleState.PLAYER_TURN or current_acting_unit == null:
		return false
	
	match action:
		"attack":
			if target == null or not current_acting_unit.can_attack(target):
				return false
			var result = current_acting_unit.attack(target)
			action_performed.emit("attack", result)
			unit_status_changed.emit(target)
		
		"move":
			if position == Vector2i.ZERO:
				return false
			var available_moves = grid.get_available_moves(current_acting_unit)
			if position in available_moves:
				grid.move_unit(current_acting_unit, position)
				action_performed.emit("move", { "unit": current_acting_unit.unit_name, "to": position })
			else:
				return false
		
		"defend":
			# Увеличиваем защиту на следующий ход (не реализовано, заглушка)
			action_performed.emit("defend", { "unit": current_acting_unit.unit_name })
		
		"use_item":
			# Использование еды/травы для лечения
			# Пока заглушка - можно реализовать позже
			action_performed.emit("use_item", { "unit": current_acting_unit.unit_name })
		
		_:
			return false
	
	_end_unit_turn()
	return true

# Завершить ход юнита
func _end_unit_turn():
	# Проверяем условие победы
	if not grid.has_alive_enemies(true):
		_end_battle(true)  # Победа игрока
		return
	
	if not grid.has_alive_enemies(false):
		_end_battle(false)  # Победа врагов
		return
	
	# Следующий ход
	_start_next_turn()

# Завершить бой
func _end_battle(player_won: bool):
	battle_state = BattleState.FINISHED
	
	# Добавляем опыт боевой (за убитых врагов)
	if player_won and ExperienceSystem:
		var killed_enemies = 0
		for enemy in enemy_units:
			if not enemy.is_alive:
				killed_enemies += 1
		ExperienceSystem.add_combat_exp(killed_enemies)
		print("[BattleController] Получен боевой опыт за %d врагов" % killed_enemies)
	
	battle_ended.emit(player_won)
	print("[BattleController] Бой окончен! Победа: %s" % ("игрока" if player_won else "врагов"))

# Получить статус боя для UI
func get_battle_status() -> Dictionary:
	var player_statuses = []
	for u in grid.get_alive_allies(true):
		player_statuses.append(u.get_status())
	
	var enemy_statuses = []
	for u in grid.get_alive_allies(false):
		enemy_statuses.append(u.get_status())
	
	return {
		"state": BattleState.keys()[battle_state],
		"current_unit": current_acting_unit.unit_name if current_acting_unit else "Никто",
		"is_player_turn": current_acting_unit.is_player_unit if current_acting_unit else false,
		"player_units": player_statuses,
		"enemy_units": enemy_statuses
	}

# Получить доступные ходы для текущего юнита
func get_current_available_moves() -> Array:
	if current_acting_unit == null:
		return []
	return grid.get_available_moves(current_acting_unit)

# Получить врагов в пределах атаки
func get_current_attackable_enemies() -> Array:
	if current_acting_unit == null:
		return []
	return grid.get_attackable_enemies(current_acting_unit)

func _on_grid_updated():
	pass  # Сетка обновилась, UI должна пересчитать визуализацию
