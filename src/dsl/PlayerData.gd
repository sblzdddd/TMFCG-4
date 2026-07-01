class_name PlayerData
extends Resource

@export var uid: String = "user-0"
@export var name: String = "Player"
@export var description: String = "A player of the game"
@export var avatar: Texture2D = null
@export var date_joined: float = Time.get_unix_time_from_system()
