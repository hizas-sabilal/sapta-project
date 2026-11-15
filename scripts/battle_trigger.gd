extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
func _on_body_entered(body: Node2D) -> void:
	print('1 triggered')
	if body.is_in_group("player"):
		print('2 triggered')
		var monster = get_parent()
		if monster and monster.has_meta("Enemies"):
			print('3 triggered')
			
			var enemies = monster.get_meta("Enemies").split(",")
			GameManager.enter_battle(enemies, monster)
