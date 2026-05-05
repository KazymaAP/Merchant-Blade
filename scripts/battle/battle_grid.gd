class_name BattleGrid

const GRID_WIDTH = 5
const GRID_HEIGHT = 5

# Массив юнитов на сетке
var grid: Array = []
var units: Array = []

signal grid_updated
signal unit_moved(unit: BattleUnit, old_pos: Vector2i, new_pos: Vector2i)

func _init():
	_initialize_grid()

# Инициализировать пустую сетку
func _initialize_grid():
	grid = []
	for x in range(GRID_WIDTH):
		var row = []
		for y in range(GRID_HEIGHT):
			row.append(null)
		grid.append(row)

# Добавить юнита на сетку
func add_unit(unit: BattleUnit, position: Vector2i) -> bool:
	if not is_valid_position(position):
		return false
	
	if grid[position.x][position.y] != null:
		return false  # Клетка занята
	
	unit.position = position
	grid[position.x][position.y] = unit
	units.append(unit)
	grid_updated.emit()
	return true

# Переместить юнита
func move_unit(unit: BattleUnit, new_position: Vector2i) -> bool:
	if not is_valid_position(new_position):
		return false
	
	if grid[new_position.x][new_position.y] != null:
		return false  # Клетка занята
	
	# Удаляем со старой позиции
	var old_pos = unit.position
	grid[old_pos.x][old_pos.y] = null
	
	# Добавляем на новую позицию
	grid[new_position.x][new_position.y] = unit
	unit.position = new_position
	
	unit_moved.emit(unit, old_pos, new_position)
	grid_updated.emit()
	return true

# Получить юнита на позиции
func get_unit_at(position: Vector2i) -> BattleUnit:
	if not is_valid_position(position):
		return null
	return grid[position.x][position.y]

# Проверить, валидна ли позиция
func is_valid_position(position: Vector2i) -> bool:
	return position.x >= 0 and position.x < GRID_WIDTH and \
	       position.y >= 0 and position.y < GRID_HEIGHT

# Получить все доступные ходы для юнита (соседние клетки)
func get_available_moves(unit: BattleUnit) -> Array:
	var moves = []
	var directions = [
		Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT,
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
	]
	
	for direction in directions:
		var new_pos = unit.position + direction
		if is_valid_position(new_pos) and grid[new_pos.x][new_pos.y] == null:
			moves.append(new_pos)
	
	return moves

# Получить врагов юнита
func get_enemies(unit: BattleUnit) -> Array:
	var enemies = []
	for other_unit in units:
		if other_unit.is_alive and other_unit.is_player_unit != unit.is_player_unit:
			enemies.append(other_unit)
	return enemies

# Получить союзников юнита (включая себя)
func get_allies(unit: BattleUnit) -> Array:
	var allies = []
	for other_unit in units:
		if other_unit.is_alive and other_unit.is_player_unit == unit.is_player_unit:
			allies.append(other_unit)
	return allies

# Получить врагов в радиусе атаки
func get_attackable_enemies(unit: BattleUnit) -> Array:
	var enemies = []
	for enemy in get_enemies(unit):
		if unit.can_attack(enemy):
			enemies.append(enemy)
	return enemies

# Удалить юнита со сетки (смерть)
func remove_unit(unit: BattleUnit):
	grid[unit.position.x][unit.position.y] = null
	units.erase(unit)
	grid_updated.emit()

# Получить состояние сетки (для отладки/сохранения)
func get_grid_state() -> Array:
	var state = []
	for unit in units:
		state.append({
			"name": unit.unit_name,
			"pos": unit.position,
			"hp": unit.current_hp,
			"alive": unit.is_alive
		})
	return state

# Получить живых врагов
func get_alive_enemies(is_player: bool) -> Array:
	var enemies = []
	for unit in units:
		if unit.is_alive and unit.is_player_unit != is_player:
			enemies.append(unit)
	return enemies

# Получить живых союзников
func get_alive_allies(is_player: bool) -> Array:
	var allies = []
	for unit in units:
		if unit.is_alive and unit.is_player_unit == is_player:
			allies.append(unit)
	return allies

# Проверить, есть ли живые враги
func has_alive_enemies(is_player: bool) -> bool:
	return get_alive_enemies(is_player).size() > 0

# Сброс сетки
func clear():
	_initialize_grid()
	units.clear()
	grid_updated.emit()
