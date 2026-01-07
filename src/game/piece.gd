class_name Piece
extends RefCounted
## Represents a chess piece with type, color, and state

enum Type { KING, QUEEN, ROOK, BISHOP, KNIGHT, PAWN }
enum Side { WHITE, BLACK }

var type: Type
var side: Side
var has_moved: bool = false


func _init(p_type: int, p_side: int) -> void:
	type = p_type as Type
	side = p_side as Side


func get_symbol() -> String:
	## Returns the algebraic notation symbol for this piece
	match type:
		Type.KING: return "K"
		Type.QUEEN: return "Q"
		Type.ROOK: return "R"
		Type.BISHOP: return "B"
		Type.KNIGHT: return "N"
		Type.PAWN: return ""
	return ""


func get_display_name() -> String:
	## Returns human-readable piece name
	var color_name := "White" if side == Side.WHITE else "Black"
	var type_name: String
	match type:
		Type.KING: type_name = "King"
		Type.QUEEN: type_name = "Queen"
		Type.ROOK: type_name = "Rook"
		Type.BISHOP: type_name = "Bishop"
		Type.KNIGHT: type_name = "Knight"
		Type.PAWN: type_name = "Pawn"
	return "%s %s" % [color_name, type_name]


func duplicate_piece() -> Piece:
	## Creates a copy of this piece
	var copy := Piece.new(type, side)
	copy.has_moved = has_moved
	return copy


func to_dict() -> Dictionary:
	## Serialize for save/load
	return {
		"type": type,
		"side": side,
		"has_moved": has_moved
	}


static func from_dict(data: Dictionary) -> Piece:
	## Deserialize from save data
	var piece := Piece.new(data["type"], data["side"])
	piece.has_moved = data.get("has_moved", false)
	return piece
