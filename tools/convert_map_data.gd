extends SceneTree

# One-off converter: writes the map's data files (res://data/*.json) from the constants the game shipped with -- RoomData.ROOMS / EDGES /
# ROADS and the landmarks and regions written in WorldMap.gd -- and then reads every file back and checks it equals what went in.
# It touches no save file. Run it again at any time to put the data files back to the factory values (the old ones are kept in
# res://data/backups/).
#
#   Godot --headless --path . --script res://tools/convert_map_data.gd
#
# Add "-- --dir=user://somewhere" to write to another folder instead of res://data.

const MapDataScript := preload("res://scripts/MapData.gd")
const RoomDataScript := preload("res://scripts/RoomData.gd")
const WorldMapScript := preload("res://scripts/WorldMap.gd")

func _init() -> void:
	var dir := MapDataScript.DIR
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--dir="):
			dir = a.substr(6)

	# The factory landmarks and regions are the ones WorldMap builds with no data files laid over them.
	RoomDataScript.use({"landmarks": [], "regions": {}})
	WorldMapScript.reset()
	WorldMapScript.ensure_built()

	var landmarks: Array = MapDataScript.landmark_entries(WorldMapScript.landmarks)
	var regions: Dictionary = MapDataScript.region_entries(WorldMapScript.regions)

	var out := {
		"rooms": RoomDataScript.factory("rooms"),
		"edges": RoomDataScript.factory("edges"),
		"roads": RoomDataScript.factory("roads"),
		"landmarks": landmarks,
		"regions": regions,
	}
	var failed := 0
	for kind in MapDataScript.KINDS:
		var res: Dictionary = MapDataScript.write(kind, out[kind], dir)
		var back: Dictionary = MapDataScript.read(kind, dir)
		var round_trips: bool = back.status == "ok" and back.warnings.is_empty() and MapDataScript.same(back.data, MapDataScript.tidy(out[kind]))
		var note := "unchanged" if res.unchanged else ("written, old one kept as %s" % res.backup if res.backup != "" else "written")
		print("%s: %s -- %s; reads back identical to the constants: %s (expected true)" % [MapDataScript.file_path(kind, dir), "ok" if res.ok else "FAILED " + str(res.error), note, round_trips])
		if not res.ok or not round_trips:
			failed += 1
	print("Converted %d rooms, %d doorways, %d roads, %d landmarks, %d regions: %s (expected 0 failures)" % [out.rooms.size(), out.edges.size(), out.roads.size(), landmarks.size(), regions.size(), failed])
	quit(1 if failed > 0 else 0)
