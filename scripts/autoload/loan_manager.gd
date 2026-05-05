extends Node

var loans: Array = []

signal loan_taken(amount: int, daily_interest: float)
signal loan_repaid(loan_id: int)
signal loan_overdue(loan_id: int)

func _ready():
	print("[LoanManager] Инициализирована")

# Взять кредит
func take_loan(amount_copper: int, days: int = 30) -> bool:
	# Макимум кредита - 5000 серебра (500000 медяков)
	if amount_copper > 500000:
		print("[LoanManager] Кредит слишком большой")
		return false
	
	var daily_interest = 0.10 / 30.0  # 10% в месяц = ~0.33% в день
	
	var loan = {
		"id": loans.size(),
		"amount": amount_copper,
		"daily_interest": daily_interest,
		"taken_at": GameManager.current_day,
		"due_day": GameManager.current_day + days,
		"paid": 0,
		"is_overdue": false
	}
	
	loans.append(loan)
	GameManager.add_money(amount_copper)
	
	loan_taken.emit(amount_copper, daily_interest)
	print("[LoanManager] Кредит %d на %d серебра (10%% в месяц)" % [loan["id"], amount_copper / 100])
	return true

# Погасить кредит
func repay_loan(loan_id: int, amount_copper: int) -> bool:
	if loan_id >= loans.size():
		return false
	
	var loan = loans[loan_id]
	if GameManager.money_in_copper < amount_copper:
		return false
	
	loan["paid"] += amount_copper
	GameManager.add_money(-amount_copper)
	
	# Если полностью погашен
	if loan["paid"] >= loan["amount"]:
		loans.remove_at(loan_id)
		loan_repaid.emit(loan_id)
		print("[LoanManager] Кредит %d погашен!" % loan_id)
	
	return true

# Обновление кредитов каждый день
func update_daily():
	for loan in loans:
		var interest = int(loan["amount"] * loan["daily_interest"])
		loan["amount"] += interest  # Проценты добавляются к сумме
		
		# Проверка просрочки
		if GameManager.current_day > loan["due_day"] and not loan["is_overdue"]:
			loan["is_overdue"] = true
			GameManager.set_reputation(maxi(0, GameManager.reputation - 20))
			loan_overdue.emit(loan["id"])
			print("[LoanManager] Кредит просрочен! Репутация -20")

# Получить список активных кредитов
func get_active_loans() -> Array:
	return loans.duplicate()

# Получить общую сумму долга
func get_total_debt() -> int:
	var total = 0
	for loan in loans:
		total += loan["amount"] - loan["paid"]
	return total

# Получить статус
func get_status() -> Dictionary:
	var total_debt = get_total_debt()
	return {
		"active_loans": loans.size(),
		"total_debt_copper": total_debt,
		"total_debt_silver": total_debt / 100
	}
