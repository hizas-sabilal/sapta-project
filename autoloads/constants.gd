extends Node

const MAX_LIVES = 3
const GRAVITY = 980
const GAME_VERSION = "1.0.0"

## Animation States
const ANIM_IDLE := "idle"
const ANIM_HURT := "hurt"
const ANIM_ATTACK := "attack"
const ANIM_DEAD := "dead"

## Enemies Path
const ENEMIES = {
	"vampire": "res://resources/monsters/vampire/vampire.tscn",
	"zombie_easy_female": "res://resources/monsters/zombie_easy_female/zombie_easy_female.tscn"
}
