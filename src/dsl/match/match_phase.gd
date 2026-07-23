class_name MatchPhase
extends RefCounted

enum Phase {
	INITIALIZATION,
	TURN_PLAY,
	ROUND_RESOLUTION,
	END_GAME_PLAY,
	GAME_OVER,
}


## Phases where a seat may select and play (or pass) cards.
static func is_play_phase(phase: Phase) -> bool:
	return phase == Phase.TURN_PLAY or phase == Phase.END_GAME_PLAY

