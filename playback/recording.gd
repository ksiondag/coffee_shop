class_name Recording
extends Resource

# Pourer input history, again ported from Unity setup following flat structure:
# dt, coord_x, coord_y, prev_coord_x, prev_coord_y, delta_x, delta_y
# Coordinates and deltas are in 0-1 texture space; dt is seconds since the
# previous row

const ROW_SIZE := 7
const DT := 0
const COORD_X := 1
const COORD_Y := 2
const PREV_COORD_X := 3
const PREV_COORD_Y := 4
const DELTA_X := 5
const DELTA_Y := 6

@export var rows: PackedFloat32Array


func row_count() -> int:
	@warning_ignore("integer_division")
	return rows.size() / ROW_SIZE


func get_dt(row: int) -> float:
	return rows[row * ROW_SIZE + DT]


func get_coord(row: int) -> Vector2:
	return Vector2(rows[row * ROW_SIZE + COORD_X], rows[row * ROW_SIZE + COORD_Y])


func get_delta(row: int) -> Vector2:
	return Vector2(rows[row * ROW_SIZE + DELTA_X], rows[row * ROW_SIZE + DELTA_Y])
