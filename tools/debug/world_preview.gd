extends Node3D
## A free-fly look at the generated world (backlog brick 091b).
##
## Backlog 091b is `HUMAN_REQUIRED`, and `docs/world-generation.md` §30.8 recorded why no
## `HUMAN_REQUIRED` row before it could be run: nothing wrote a voxel. Now something does — but
## the project still has no player, no camera and no gameplay scene, all of which are Phase F
## (bricks 115-122, 212). This is a **development tool**, filed under `tools/` with the
## benchmarks and generators for exactly that reason: it exists so a human can look at what
## `WorldGenerator` produces, and it deliberately implements none of the movement, collision or
## camera contracts Phase F owns. Nothing in `client/` or `gameplay/` should ever read it.
##
## ```powershell
## tools\scripts\godot.ps1 res://tools/debug/world_preview.tscn
## tools\scripts\godot.ps1 res://tools/debug/world_preview.tscn -- --seed=lakes --view-distance=48
## ```
##
## Controls: mouse look, `WASD` move, `Q`/`E` down/up, `Shift` fast, `Escape` release the mouse,
## click to recapture.
##
## **View distance defaults low, and that is a real measurement, not caution.** Generation is
## per-column GDScript noise costing roughly a third of a second per 16³ chunk at this brick
## (`docs/performance-budget.md` §4), so the project's own `DEFAULT_VIEW_DISTANCE` of 128 asks
## for thousands of chunks. `--view-distance=` raises it for anyone who wants to wait.

const DEFAULT_SEED_TEXT := "cubeworld"
const DEFAULT_VIEW_DISTANCE := 48

const _MOVE_SPEED_MPS := 12.0
const _FAST_MULTIPLIER := 6.0
const _LOOK_SENSITIVITY := 0.0022
const _PITCH_LIMIT := 1.5
const _SPAWN_HEIGHT_VOXELS := 6

## The HUD asks `column_at()`, which runs the whole height chain and a nine-region structure
## scan. Doing that every frame would spend a core competing with the generation threads the
## tool exists to watch, so it refreshes four times a second instead.
const _STATUS_INTERVAL_SEC := 0.25

var _generator: WorldGenerator
var _terrain: VoxelTerrain
var _camera: Camera3D
var _status: Label
var _yaw := 0.0
var _pitch := -0.2
var _status_age := _STATUS_INTERVAL_SEC


func _ready() -> void:
	var seed_text := _argument("seed", DEFAULT_SEED_TEXT)
	var view_distance := int(_argument("view-distance", str(DEFAULT_VIEW_DISTANCE)))

	var blocks := BlockSet.load_default()
	var biomes := BiomeCatalog.load_default()
	var world_seed := WorldSeed.from_text(seed_text)
	_terrain = VoxelTerrainBuilder.build_world(world_seed, blocks, biomes)
	if _terrain == null:
		Log.error(Log.CH_GEN, "world preview: the world could not be built",
				{"seed": seed_text})
		return
	_generator = _terrain.generator as WorldGenerator
	_terrain.max_view_distance = view_distance
	add_child(_terrain)

	_build_camera(view_distance)
	_build_scenery()
	_build_hud()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Log.info(Log.CH_GEN, "world preview ready", {
		"seed": world_seed.display_text(),
		"generation_version": _generator.generation_version(),
		"view_distance": view_distance,
	})


## Places the camera above the generated ground at the world origin, with the streaming viewer
## parented to it — `docs/voxel-tools.md` §9's own note that a `VoxelViewer` is a `Node3D` that
## follows whatever it is attached to, not a terrain property.
func _build_camera(view_distance: int) -> void:
	var ground_y := _generator.column_at(Vector2i(0, 0)).ground_y
	_camera = Camera3D.new()
	_camera.far = maxf(1024.0, float(view_distance) * 4.0)
	_camera.position = Vector3(0.0, float(ground_y + _SPAWN_HEIGHT_VOXELS), 0.0)
	add_child(_camera)

	var viewer := VoxelViewerBuilder.build() as VoxelViewer
	viewer.view_distance = view_distance
	_camera.add_child(viewer)


## A sun and an ambient sky. `VoxelMesherBlocky` bakes ambient occlusion into vertex colours
## (040) but nothing in this project has ever needed a light before, and an unlit Forward+ scene
## renders the whole world black.
func _build_scenery() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, -0.6, 0.0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.6
	var holder := WorldEnvironment.new()
	holder.environment = environment
	add_child(holder)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_status = Label.new()
	_status.position = Vector2(12, 12)
	layer.add_child(_status)


# ---------------------------------------------------------------------------
# Free-fly control — a debug camera, not brick 116's player controller
# ---------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * _LOOK_SENSITIVITY
		_pitch = clampf(_pitch - motion.relative.y * _LOOK_SENSITIVITY,
				-_PITCH_LIMIT, _PITCH_LIMIT)
	elif event is InputEventKey and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if _camera == null:
		return
	_camera.rotation = Vector3(_pitch, _yaw, 0.0)

	var wish := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		wish -= _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_S):
		wish += _camera.global_transform.basis.z
	if Input.is_key_pressed(KEY_A):
		wish -= _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_D):
		wish += _camera.global_transform.basis.x
	if Input.is_key_pressed(KEY_E):
		wish += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		wish -= Vector3.UP

	var speed := WorldScale.mps_to_ups(_MOVE_SPEED_MPS)
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= _FAST_MULTIPLIER
	if wish != Vector3.ZERO:
		_camera.position += wish.normalized() * speed * delta

	_status_age += delta
	if _status_age >= _STATUS_INTERVAL_SEC:
		_status_age = 0.0
		_status.text = "\n".join(_report())


## What the world says about the column the camera is over — the whole point of the tool: a
## human comparing what they see against what the passes claim is there.
func _report() -> PackedStringArray:
	var position := _camera.position
	var column := GenerationGrid.voxel_to_column(WorldScale.world_to_voxel(position))
	var plan := _generator.column_at(column)
	var lines: PackedStringArray = []
	lines.append("seed %s   gen v%d" % [
			_generator.world_seed().display_text(), _generator.generation_version()])
	lines.append("camera %.0f %.0f %.0f" % [position.x, position.y, position.z])
	lines.append("column %s   ground y=%d (terrace %d)" % [column, plan.ground_y, plan.terrace_y])
	lines.append("biome %s   cover %s" % [
			_generator.cover().shoreline().surface().biome_id_at(column),
			_generator.cover_block_id_at(column)])
	if plan.has_structure():
		lines.append("structure @ %s  base y=%d" % [plan.site.anchor_column, plan.site.base_y])
	lines.append("WASD/QE move · Shift fast · Esc release mouse")
	return lines


## Reads `--name=value` from the arguments after `--`, or `fallback`. `OS.get_cmdline_user_args()`
## is the same source `tools/scripts/run.ps1` forwards game arguments into.
static func _argument(name: String, fallback: String) -> String:
	var prefix := "--%s=" % name
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return fallback
