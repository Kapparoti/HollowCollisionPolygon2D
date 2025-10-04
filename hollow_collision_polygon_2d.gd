extends CollisionPolygon2D
class_name HollowCollisionPolygon2D


@export var use_long_search: bool = false


#-------------------------------------------------------------  Public helper functions
func is_valid_polygon(poly: PackedVector2Array) -> bool:
	if Geometry2D.is_polygon_clockwise(poly):
		return false
	var triangs: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var polys: Array[PackedVector2Array] = Geometry2D.decompose_polygon_in_convex(poly)
	if triangs.size() > 0:
		return polys.size() > 1
	return false

func shift_vector(poly: PackedVector2Array, amount: int) -> PackedVector2Array:
	if amount == 0:
		return poly.duplicate()
	
	var result: PackedVector2Array = PackedVector2Array()
	var poly_size: int = poly.size()
	for i: int in poly_size:
		var index: int = amount + i
		if index >= poly_size:
			index -= poly_size
		result.append(poly[index])
	return result

#-------------------------------------------------------------  Private helper functions
func _is_there_clockwise(polygons: Array[PackedVector2Array]) -> bool:
	for poly: PackedVector2Array in polygons:
		if Geometry2D.is_polygon_clockwise(poly):
			return true
	return false

func _insert_vectors(vector_a: PackedVector2Array, vector_b: PackedVector2Array, is_single_hole: bool, a_index: int) -> PackedVector2Array:
	var start_polygon: PackedVector2Array
	var end_polygon: PackedVector2Array
	
	# We split the receiving vector_a in two
	start_polygon = vector_a.slice(0, a_index)
	end_polygon = vector_a.slice(a_index)
	
	# If we are doing a single hole, we need to add the "connection to the walls"
	if is_single_hole:
		start_polygon.append(vector_a[a_index])
		end_polygon.insert(0, vector_b[0])
	
	# We close the vector sandwich
	start_polygon.append_array(vector_b)
	start_polygon.append_array(end_polygon)
	return start_polygon

#-------------------------------------------------------------  Main clip funciton
func clip_polygons(polygon_a: PackedVector2Array, polygon_b: PackedVector2Array) -> Array[PackedVector2Array]:
	polygon_a = polygon_a.duplicate()
	polygon_b = polygon_b.duplicate()
	
	# Try Geometry2D clipping (only works for the borders)
	var clipped: Array[PackedVector2Array] = Geometry2D.clip_polygons(polygon_a, polygon_b)
	
	# Check if there is a hole (clockwise polygon) in the clipped result
	var clockwise: bool = _is_there_clockwise(clipped)
	
	# If there aren't any holes, we can just return it
	if not clipped.is_empty() and not clockwise:
		return clipped
	
	# In some cases (like on the borders), the clip returns both a correct polygon and clockwise holes
	if clipped.size() == 2 and clockwise:
		# So we can try to work on them
		var new_clipped: Array[PackedVector2Array] = _clip_polygons(clipped[0], clipped[1])
		if not new_clipped.is_empty() and not _is_there_clockwise(new_clipped):
			return new_clipped
	
	# For all the other cases, like the first hole:
	return _clip_polygons(polygon_a, polygon_b)

func _clip_polygons(polygon_a: PackedVector2Array, polygon_b: PackedVector2Array) -> Array[PackedVector2Array]:
	# First, we will remove the points that arent in the clipping. This will only work with small simple shapes!
	var new_hole: bool = true
	
	# Remove the points of polygon_a inside of polygon_b (they will be removed)
	var new_polygon_a: PackedVector2Array = PackedVector2Array()
	for a_point: Vector2 in polygon_a:
		if not Geometry2D.is_point_in_polygon(a_point, polygon_b):
			new_polygon_a.append(a_point)
			continue
		
		# If some points get removed from polygon_a, we know that there won't be a new hole, but an extension
		new_hole = false
	
	# Remove the points of polygon_b outside of polygon a (the others don't impact)
	var new_polygon_b: PackedVector2Array = PackedVector2Array()
	for b_point: Vector2 in polygon_b:
		if Geometry2D.is_point_in_polygon(b_point, polygon_a):
			new_polygon_b.append(b_point)
			continue
		
		# If some points get removed from polygon_b, we know that there won't be a new hole, but an extension
		new_hole = false
	
	# For the initial soft try, we need to find the nearest point couple of polygon_a to polygon_b
	var nearest_a_point_index: int = 0
	var nearest_b_point_index: int = 0
	var nearest_distance: float = INF
	for a: int in new_polygon_a.size():
		for b: int in new_polygon_b.size():
			var distance: float = (new_polygon_a[a] - new_polygon_b[b]).length()
			if distance < nearest_distance:
				nearest_distance = distance
				nearest_a_point_index = a
				nearest_b_point_index = b
	
	# If polygon_b has all its initial points, we can shift it without consequences
	if new_hole:
		new_polygon_b = shift_vector(new_polygon_b, nearest_b_point_index)
	
	# In a first soft try, we insert the polygon_b from the nearest point couble
	var result_polygon: PackedVector2Array = _insert_vectors(new_polygon_a, new_polygon_b, new_hole, nearest_a_point_index)
	if is_valid_polygon(result_polygon):
		return [result_polygon]
	
	# Soft reverse try
	new_polygon_b.reverse()
	result_polygon = _insert_vectors(new_polygon_a, new_polygon_b, new_hole, nearest_a_point_index)
	if is_valid_polygon(result_polygon):
		return [result_polygon]
	
	# Normal try (try all the polygon_a points, not only the nearest)
	new_polygon_b.reverse()
	for a: int in polygon_a.size():
		result_polygon = _insert_vectors(new_polygon_a, new_polygon_b, new_hole, a)
		if is_valid_polygon(result_polygon):
			return [result_polygon]
	
	# Normal reversed try
	new_polygon_b.reverse()
	for a: int in polygon_a.size():
		result_polygon = _insert_vectors(new_polygon_a, new_polygon_b, new_hole, a)
		if is_valid_polygon(result_polygon):
			return [result_polygon]
	
	if not new_hole or not use_long_search:
		return []
	
	# Long try (try all points couples from the two polygons)
	new_polygon_b.reverse()
	for a: int in polygon_a.size():
		for b: int in new_polygon_b.size():
			result_polygon = _insert_vectors(new_polygon_a, shift_vector(new_polygon_b, b), new_hole, a)
			if is_valid_polygon(result_polygon):
				return [result_polygon]
	
	# Long reversed try
	new_polygon_b.reverse()
	for a: int in polygon_a.size():
		for b: int in new_polygon_b.size():
			result_polygon = _insert_vectors(new_polygon_a, shift_vector(new_polygon_b, b), new_hole, a)
			if is_valid_polygon(result_polygon):
				return [result_polygon]
	
	return []
