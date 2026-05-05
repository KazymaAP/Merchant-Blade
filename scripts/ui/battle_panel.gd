extends PanelContainer

@onready var grid_container = $VBoxContainer/GridPanel/GridContainer
@onready var action_container = $VBoxContainer/ActionPanel/ActionContainer
@onready var status_label = $VBoxContainer/StatusLabel
@onready var log_container = $VBoxContainer/LogPanel/LogContainer

var battle_controller: BattleController
var grid_cell_buttons: Dictionary = {}
var unit_cell_map: Dictionary = {}  # { position: unit }
var player_unit: PlayerUnit
var current_enemies: Array = []

const GRID_BUTTON_SIZE = 40

func _ready():
	# Подключаемся к сигналам игры
	GameManager.battle_triggered.connect(_on_battle_triggered)
	GameManager.battle_finished.connect(_on_battle_finished)
	
	# Создаём BattleController
	if not battle_controller:
		battle_controller = BattleController.new()
		battle_controller.battle_started.connect(_on_battle_started)
		battle_controller.battle_ended.connect(_on_battle_ended)
		battle_controller.turn_changed.connect(_on_turn_changed)
		battle_controller.action_performed.connect(_on_action_performed)

# Обработчик начала боя
func _on_battle_triggered(enemies: Array):
	current_enemies = enemies
	_start_battle_ui(enemies)

# Начать боевой интерфейс
func _start_battle_ui(enemies: Array):
	print("[BattlePanel] Инициализируем боевой интерфейс с %d врагами" % enemies.size())
	
	# Создаём игрока
	player_unit = PlayerUnit.new()
	player_unit.unit_name = "Вы"
	player_unit.max_hp = 100
	player_unit.current_hp = 100
	player_unit.attack_power = 10
	player_unit.defense = 5
	
	# Инициализируем боевой контроллер
	var players = [player_unit]
	battle_controller.start_battle(players, enemies)
	
	_create_grid_buttons()
	_update_ui()

# Инициализировать боевой UI
func setup_battle(controller: BattleController):
	battle_controller = controller
	
	battle_controller.battle_started.connect(_on_battle_started)
	battle_controller.battle_ended.connect(_on_battle_ended)
	battle_controller.turn_changed.connect(_on_turn_changed)
	battle_controller.action_performed.connect(_on_action_performed)
	
	_create_grid_buttons()
	_update_ui()

# Создать кнопки для сетки
func _create_grid_buttons():
	# Очищаем старые кнопки
	for child in grid_container.get_children():
		child.queue_free()
	grid_cell_buttons.clear()
	
	# Создаём кнопки для каждой клетки
	for x in range(5):
		for y in range(5):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(GRID_BUTTON_SIZE, GRID_BUTTON_SIZE)
			btn.text = ""
			var pos = Vector2i(x, y)
			btn.pressed.connect(_on_cell_clicked.bindv([pos]))
			grid_container.add_child(btn)
			grid_cell_buttons[pos] = btn

# Обновить визуализацию сетки
func _update_grid():
	# Очищаем все кнопки
	for btn in grid_cell_buttons.values():
		btn.text = ""
		btn.modulate = Color.WHITE
	
	# Отмечаем позиции юнитов
	for unit in battle_controller.grid.units:
		var pos = unit.position
		if grid_cell_buttons.has(pos):
			var btn = grid_cell_buttons[pos]
			
			# Выбираем цвет по типу юнита
			if unit.is_player_unit:
				btn.modulate = Color.GREEN
				btn.text = "A"  # Ally
			else:
				btn.modulate = Color.RED
				btn.text = "E"  # Enemy
			
			# Показываем HP
			btn.text += "\n%d" % unit.current_hp
			unit_cell_map[pos] = unit
	
	# Отмечаем доступные ходы для текущего юнита
	if battle_controller.battle_state == BattleController.BattleState.PLAYER_TURN:
		var moves = battle_controller.get_current_available_moves()
		for move in moves:
			if grid_cell_buttons.has(move):
				grid_cell_buttons[move].modulate = Color.BLUE

# Обработчик клика по клетке
func _on_cell_clicked(position: Vector2i):
	if battle_controller.battle_state != BattleController.BattleState.PLAYER_TURN:
		return
	
	# Проверяем, враг ли на этой клетке
	var unit_at_pos = battle_controller.grid.get_unit_at(position)
	
	if unit_at_pos != null and not unit_at_pos.is_player_unit:
		# Атакуем врага
		battle_controller.perform_player_action("attack", unit_at_pos)
	else:
		# Двигаемся
		battle_controller.perform_player_action("move", null, position)
	
	_update_grid()

# События боевой системы
func _on_battle_started():
	_update_ui()
	_add_log("⚔️ БОЙ НАЧАЛСЯ!")

func _on_battle_ended(player_won: bool):
	_add_log("✨ БОЙ ОКОНЧЕН! %s" % ("Победа!" if player_won else "Поражение..."))
	_update_ui()
	
	# Уведомляем GameManager о результатах
	var enemies_defeated = []
	for enemy in current_enemies:
		if not enemy.is_alive:
			enemies_defeated.append(enemy)
	
	GameManager.finish_battle(player_won, enemies_defeated)

func _on_turn_changed(unit: BattleUnit, is_player: bool):
	_add_log("Ход: %s %s" % ["(ваш)" if is_player else "(враг)", unit.unit_name])
	_update_grid()

func _on_action_performed(action: String, result: Dictionary):
	match action:
		"attack":
			var msg = "%s атакует %s" % [result["attacker"], result["target"]]
			if result["hit"]:
				msg += " - ПОПАДАНИЕ! Урон: %d" % result["damage"]
				if result["critical"]:
					msg += " (КРИТ!)"
			else:
				msg += " - ПРОМАХ!"
			_add_log(msg)
		
		"move":
			_add_log("%s переместился на позицию %s" % [result["unit"], result["to"]])
		
		"defend":
			_add_log("%s занял оборону" % result["unit"])

# Обработчик завершения боя
func _on_battle_finished(player_won: bool, loot: Dictionary):
	if player_won:
		_add_log("💰 Получена добыча: %d медяков" % loot.get("copper", 0))
	else:
		_add_log("💔 Потеряно товаров: %d единиц" % loot.get("goods_recovered", 0))

# Обновить весь UI
func _update_ui():
	if battle_controller == null:
		return
	
	var status = battle_controller.get_battle_status()
	status_label.text = "Ход: %s | %s" % [status["current_unit"], status["state"]]
	
	_update_grid()

# Добавить сообщение в лог
func _add_log(message: String):
	var label = Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	log_container.add_child(label)
	
	# Удаляем старые сообщения (более 20)
	if log_container.get_child_count() > 20:
		log_container.get_child(0).queue_free()

