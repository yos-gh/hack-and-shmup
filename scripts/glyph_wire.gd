extends RefCounted
## Authoring edges: retain silhouette/creases, omit coplanar triangulation.
static func build(mesh: Mesh) -> ArrayMesh:
	var edges: Dictionary = {}
	var arrays := mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in range(points.size()): indices.append(i)
	for i in range(0,indices.size(),3):
		var a := points[indices[i]]
		var b := points[indices[i+1]]
		var c := points[indices[i+2]]
		var normal := (b-a).cross(c-a).normalized()
		for pair in [[a,b],[b,c],[c,a]]:
			var p: Vector3 = pair[0].snapped(Vector3.ONE*0.0001)
			var q: Vector3 = pair[1].snapped(Vector3.ONE*0.0001)
			var key: String = str(p)+str(q) if str(p)<str(q) else str(q)+str(p)
			if not edges.has(key): edges[key] = {"a":p,"b":q,"normals":[]}
			edges[key].normals.append(normal)
	var vertices := PackedVector3Array()
	var endpoints := PackedFloat32Array()
	var uv := PackedVector2Array()
	for edge in edges.values():
		var crease: bool = edge.normals.size() == 1
		for n in edge.normals:
			if n.dot(edge.normals[0]) < 0.7: crease = true
		if not crease or edge.a.distance_squared_to(edge.b)<0.000001: continue
		for corner in [Vector2(0,-1),Vector2(1,-1),Vector2(1,1),Vector2(0,-1),Vector2(1,1),Vector2(0,1)]:
			vertices.append(edge.a)
			endpoints.append_array(PackedFloat32Array([edge.b.x,edge.b.y,edge.b.z,0.0]))
			uv.append(corner)
	var result: Array = []
	result.resize(Mesh.ARRAY_MAX)
	result[Mesh.ARRAY_VERTEX] = vertices
	result[Mesh.ARRAY_CUSTOM0] = endpoints
	result[Mesh.ARRAY_TEX_UV] = uv
	var output := ArrayMesh.new()
	output.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,result,[],{},Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)
	return output
