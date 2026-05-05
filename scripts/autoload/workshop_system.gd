extends Node

var workshops: Dictionary = {}  # { city_index: [workshops] }
var daily_production: Dictionary = {}

signal item_produced(workshop_id: String, item: Dictionary)
signal workshop_purchased(workshop_id: String)

func _ready():
	_initialize_workshops()
	print("[WorkshopSystem] Инициализировано мастерских")

# Инициализировать мастерские в городах
func _initialize_workshops():
	workshops = {
		0: [  # Город А
			{
				"id": "carpentry_a",
				"name": "Столярная мастерская",
				"city": 0,
				"produces": 4,  # Дерево
				"daily_production": 5,
				"cost": 2000,
				"owner": null,  # null = не куплена
				"profit_per_day": 50
			},
			{
				"id": "smith_a",
				"name": "Кузница",
				"city": 0,
				"produces": 3,  # Железо
				"daily_production": 3,
				"cost": 3000,
				"owner": null,
				"profit_per_day": 100
			}
		],
		1: [  # Город Б
			{
				"id": "mill_b",
				"name": "Мельница",
				"city": 1,
				"produces": 1,  # Зерно
				"daily_production": 10,
				"cost": 2500,
				"owner": null,
				"profit_per_day": 75
			}
		],
		2: [  # Город В
			{
				"id": "winery_c",
				"name": "Винодельня",
				"city": 2,
				"produces": 5,  # Вино
				"daily_production": 2,
				"cost": 5000,
				"owner": null,
				"profit_per_day": 200
			}
		]
	}

# Получить мастерские в городе
func get_workshops_in_city(city_index: int) -> Array:
	return workshops.get(city_index, [])

# Купить мастерскую
func buy_workshop(workshop_id: String) -> bool:
	for city_workshops in workshops.values():
		for workshop in city_workshops:
			if workshop["id"] == workshop_id:
				if workshop["owner"] != null:
					return false  # Уже куплена
				
				if GameManager.money_in_copper < workshop["cost"]:
					return false  # Недостаточно денег
				
				GameManager.add_money(-workshop["cost"])
				workshop["owner"] = "player"
				workshop_purchased.emit(workshop_id)
				print("[WorkshopSystem] Мастерская '%s' куплена за %d медяков" % [workshop["name"], workshop["cost"]])
				return true
	
	return false

# Обновить производство (вызывается каждый день)
func update_production():
	for city_workshops in workshops.values():
		for workshop in city_workshops:
			if workshop["owner"] == "player":
				# Производим товары
				var produced_good = workshop["produces"]
				var quantity = workshop["daily_production"]
				GameManager.add_item(produced_good, quantity)
				
				# Получаем прибыль (автоматически)
				GameManager.add_money(workshop["profit_per_day"])
				
				item_produced.emit(workshop["id"], {
					"good_id": produced_good,
					"quantity": quantity,
					"profit": workshop["profit_per_day"]
				})

# Получить все купленные мастерские
func get_owned_workshops() -> Array:
	var owned = []
	for city_workshops in workshops.values():
		for workshop in city_workshops:
			if workshop["owner"] == "player":
				owned.append(workshop)
	return owned

# Получить ежедневный доход от мастерских
func get_daily_workshop_income() -> int:
	var income = 0
	for workshop in get_owned_workshops():
		income += workshop["profit_per_day"]
	return income

# Получить статус мастерских
func get_status() -> Dictionary:
	return {
		"owned": get_owned_workshops().size(),
		"daily_income": get_daily_workshop_income(),
		"workshops": get_owned_workshops().map(func(w): return {
			"name": w["name"],
			"city": w["city"],
			"profit_per_day": w["profit_per_day"]
		})
	}
