extends Node


func _ready() -> void:
	_refresh_polygon_number_label()
	create_hole(Vector2.ZERO, $Area2D/HollowCollisionPolygon2D)

#-------------------------------------------------------------  Helper functions
func _get_shape_idx_polygon(shape_idx: int) -> CollisionPolygon2D:
	return $Area2D.shape_owner_get_owner($Area2D.shape_find_owner(shape_idx))


func _refresh_polygon_number_label() -> void:
	$CanvasLayer/PolygonNumberLabel.text = "Polygon number: %d" %$Area2D.get_child_count()

func _refresh_mouse_inside_label(value: bool) -> void:
	if value:
		$CanvasLayer/MouseInsideLabel.text = "Mouse: inside"
	else:
		$CanvasLayer/MouseInsideLabel.text = "Mouse: outside"


func _create_circle_polygon(center: Vector2, radius: float, segments: int = 16) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in range(segments, 0, -1):
		var a: float = TAU * i / segments
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts

#-------------------------------------------------------------  Mouse events
func _on_area_2d_mouse_entered() -> void:
	$Area2D.modulate = Color.BLACK
	_refresh_mouse_inside_label(true)

func _on_area_2d_mouse_exited() -> void:
	$Area2D.modulate = Color.WHITE
	_refresh_mouse_inside_label(false)


func _on_example_input_event(_viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action(&"click"):
		create_hole($Area2D.get_local_mouse_position(), _get_shape_idx_polygon(shape_idx))

#-------------------------------------------------------------  Create hole in the polygon
const RADIUS: float = 30

const DECOMPOSE_POLYGONS: bool = true


func create_hole(center: Vector2, dissolved_polygon: HollowCollisionPolygon2D) -> void:
	var circle_polygon: PackedVector2Array = _create_circle_polygon(center, RADIUS, 20)
	var result_polygons: Array[PackedVector2Array] = []
	if DECOMPOSE_POLYGONS:
		for collision_polygon: HollowCollisionPolygon2D in $Area2D.get_children():
			result_polygons = dissolved_polygon.clip_polygons(collision_polygon.polygon, circle_polygon)
			
			var decomposed_polygons: Array[PackedVector2Array] = []
			for polygon: PackedVector2Array in result_polygons:
				decomposed_polygons.append_array(Geometry2D.decompose_polygon_in_convex(polygon))
			
			if collision_polygon:
				modify_polygon(collision_polygon, decomposed_polygons)
	else:
		result_polygons = dissolved_polygon.clip_polygons(dissolved_polygon.polygon, circle_polygon)
		
		modify_polygon(dissolved_polygon, result_polygons)
	_refresh_polygon_number_label()


func modify_polygon(modified_polygon: HollowCollisionPolygon2D, new_polygons: Array[PackedVector2Array]) -> void:
	if new_polygons.size() == 0:
		$Area2D.remove_child(modified_polygon)
		modified_polygon.queue_free()
		return
	
	modified_polygon.polygon = new_polygons[0]
	if new_polygons.size() == 1:
		return
	
	for i: int in range(1, new_polygons.size()):
		var new_hollow_polygon: HollowCollisionPolygon2D = HollowCollisionPolygon2D.new()
		new_hollow_polygon.polygon = new_polygons[i]
		$Area2D.add_child(new_hollow_polygon)
