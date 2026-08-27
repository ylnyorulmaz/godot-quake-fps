extends RefCounted
## Deathmatch layout ids. ArenaGenerator reads these; title screen writes GameState.arena_layout.

const YARD := 0
const TIGHT := 1
const YARD_FLOOR := 100.0
const TIGHT_FLOOR := 64.0


static func floor_size(layout_id: int) -> float:
	return TIGHT_FLOOR if layout_id == TIGHT else YARD_FLOOR


static func is_tight(layout_id: int) -> bool:
	return layout_id == TIGHT
