extends Node3D

const ROAD_LENGTH: float = 60.0
const ROAD_SEGMENTS: int = 5
const MAX_SPEED: float = 62.0
const NITRO_SPEED: float = 88.0
const STEER_SPEED: float = 10.0
const ROAD_LIMIT: float = 4.5

var player_car: Node3D
var camera: Camera3D
var road_segments: Array[Node3D] = []
var opponent_cars: Array[Node3D] = []

var speed: float = 28.0
var score: float = 0.0
var nitro: float = 100.0

var steering_left: bool = false
var steering_right: bool = false
var braking: bool = false
var nitro_active: bool = false

var paused: bool = false
var crashed: bool = false

var hud_label: Label
var speed_label: Label
var nitro_label: Label
var message_label: Label
var pause_button: Button
var restart_button: Button
var nitro_button: Button

var ui_layer: CanvasLayer
var cockpit_camera: Camera3D
var camera_mode: int = 0 # 0 = chase camera, 1 = cockpit
var camera_button: Button
var steering_wheel_control: Control
var steering_wheel_label: Label
var wheel_dragging: bool = false
var engine_audio: AudioStreamPlayer
var brake_audio: AudioStreamPlayer
var nitro_audio: AudioStreamPlayer
var crash_audio: AudioStreamPlayer
var last_braking: bool = false


func _ready() -> void:
    randomize()

    _create_environment()
    _create_road()
    _create_player()
    _create_opponents()
    _create_camera()
    _create_audio()
    _create_ui()

    _update_hud()


func _process(delta: float) -> void:
    _update_audio(delta)
    if paused or crashed:
        return

    _update_speed(delta)
    _update_player(delta)
    _update_road(delta)
    _update_opponents(delta)
    _update_camera(delta)
    _update_score(delta)
    _update_hud()


# --------------------------------------------------
# ENVIRONMENT
# --------------------------------------------------

func _create_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()

    environment.background_mode = Environment.BG_SKY

    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()

    sky_material.sky_top_color = Color(0.12, 0.30, 0.55)
    sky_material.sky_horizon_color = Color(0.70, 0.82, 0.94)
    sky_material.ground_bottom_color = Color(0.08, 0.10, 0.12)
    sky_material.ground_horizon_color = Color(0.45, 0.50, 0.55)

    sky.sky_material = sky_material
    environment.sky = sky
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.65, 0.72, 0.85)
    environment.ambient_light_energy = 0.85
    environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    environment.tonemap_exposure = 1.05
    environment.ssr_enabled = false
    environment.glow_enabled = true
    environment.glow_intensity = 0.25

    world_environment.environment = environment
    add_child(world_environment)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 90.0
    add_child(sun)


# --------------------------------------------------
# MATERIALS AND GEOMETRY
# --------------------------------------------------

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = metallic
    result.roughness = 0.28 if metallic > 0.3 else 0.62
    return result


func _box(
    parent: Node3D,
    size: Vector3,
    position: Vector3,
    color: Color,
    metallic: float = 0.0
) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()

    mesh.size = size
    instance.mesh = mesh
    instance.position = position
    instance.material_override = _material(color, metallic)

    parent.add_child(instance)
    return instance


func _create_car(
    parent: Node3D,
    body_color: Color,
    player: bool
) -> Node3D:
    var car := Node3D.new()
    parent.add_child(car)

    # Main body
    _box(
        car,
        Vector3(1.8, 0.55, 3.5),
        Vector3(0.0, 0.75, 0.0),
        body_color,
        0.55
    )

    # Front hood
    _box(
        car,
        Vector3(1.72, 0.20, 1.05),
        Vector3(0.0, 0.99, -1.05),
        body_color,
        0.45
    )

    # Cabin
    _box(
        car,
        Vector3(1.25, 0.55, 1.55),
        Vector3(0.0, 1.24, 0.10),
        Color(0.08, 0.16, 0.23),
        0.3
    )

    # Windshield
    _box(
        car,
        Vector3(1.12, 0.34, 0.08),
        Vector3(0.0, 1.29, -0.68),
        Color(0.25, 0.55, 0.72),
        0.2
    )

    # Rear window
    _box(
        car,
        Vector3(1.10, 0.30, 0.08),
        Vector3(0.0, 1.29, 0.85),
        Color(0.16, 0.30, 0.42),
        0.2
    )

    # Wheels
    var wheel_positions: Array[Vector3] = [
        Vector3(-0.94, 0.40, -1.08),
        Vector3(0.94, 0.40, -1.08),
        Vector3(-0.94, 0.40, 1.08),
        Vector3(0.94, 0.40, 1.08)
    ]

    for wheel_position in wheel_positions:
        var wheel := MeshInstance3D.new()
        var wheel_mesh := CylinderMesh.new()

        wheel_mesh.top_radius = 0.34
        wheel_mesh.bottom_radius = 0.34
        wheel_mesh.height = 0.22

        wheel.mesh = wheel_mesh
        wheel.position = wheel_position
        wheel.rotation_degrees.z = 90.0
        wheel.material_override = _material(
            Color(0.035, 0.04, 0.05)
        )

        car.add_child(wheel)

    # Headlights
    _box(
        car,
        Vector3(0.38, 0.12, 0.07),
        Vector3(-0.52, 0.88, -1.77),
        Color(0.75, 0.92, 1.0)
    )

    _box(
        car,
        Vector3(0.38, 0.12, 0.07),
        Vector3(0.52, 0.88, -1.77),
        Color(0.75, 0.92, 1.0)
    )

    # Rear lights
    _box(
        car,
        Vector3(0.40, 0.12, 0.07),
        Vector3(-0.52, 0.88, 1.77),
        Color(1.0, 0.04, 0.025)
    )

    _box(
        car,
        Vector3(0.40, 0.12, 0.07),
        Vector3(0.52, 0.88, 1.77),
        Color(1.0, 0.04, 0.025)
    )

    # More sculpted sports-car details: lower splitter, side skirts, mirrors,
    # grille, metallic wheels and brake discs. These are procedural meshes so
    # the game remains self-contained and works offline.
    _box(car, Vector3(1.72, 0.12, 0.30), Vector3(0.0, 0.49, -1.73), Color(0.035, 0.04, 0.05), 0.25)
    _box(car, Vector3(0.48, 0.12, 0.12), Vector3(0.0, 0.70, -1.79), Color(0.04, 0.05, 0.06), 0.35)
    _box(car, Vector3(0.12, 0.18, 1.85), Vector3(-0.87, 0.53, 0.05), body_color, 0.4)
    _box(car, Vector3(0.12, 0.18, 1.85), Vector3(0.87, 0.53, 0.05), body_color, 0.4)
    _box(car, Vector3(0.20, 0.10, 0.34), Vector3(-0.91, 1.12, -0.40), body_color, 0.45)
    _box(car, Vector3(0.20, 0.10, 0.34), Vector3(0.91, 1.12, -0.40), body_color, 0.45)
    # Wheel hubs and brake details
    for wheel_position in wheel_positions:
        var hub := MeshInstance3D.new()
        var hub_mesh := CylinderMesh.new()
        hub_mesh.top_radius = 0.16
        hub_mesh.bottom_radius = 0.16
        hub_mesh.height = 0.235
        hub.mesh = hub_mesh
        hub.position = wheel_position
        hub.rotation_degrees.z = 90.0
        hub.material_override = _material(Color(0.58, 0.62, 0.68), 0.8)
        car.add_child(hub)
        for spoke_index in range(5):
            var spoke := _box(car, Vector3(0.045, 0.035, 0.23), wheel_position + Vector3(0.0, 0.0, 0.0), Color(0.78, 0.82, 0.88), 0.85)
            spoke.rotation.z = float(spoke_index) * TAU / 5.0
            spoke.position += Vector3(0.0, cos(float(spoke_index) * TAU / 5.0) * 0.10, sin(float(spoke_index) * TAU / 5.0) * 0.10)
    # Hood vents add visual detail
    for vent_index in range(3):
        _box(car, Vector3(0.09, 0.025, 0.48), Vector3(-0.30 + float(vent_index) * 0.30, 1.105, -1.00), Color(0.045, 0.055, 0.065), 0.2)

    if player:
        # Decorative rear spoiler
        _box(
            car,
            Vector3(1.65, 0.10, 0.24),
            Vector3(0.0, 1.25, 1.45),
            body_color,
            0.5
        )

    return car


# --------------------------------------------------
# ROAD
# --------------------------------------------------

func _create_road() -> void:
    for index in range(ROAD_SEGMENTS):
        var segment := Node3D.new()
        segment.position.z = -float(index) * ROAD_LENGTH
        add_child(segment)

        _box(
            segment,
            Vector3(14.0, 0.25, ROAD_LENGTH),
            Vector3(0.0, -0.18, -ROAD_LENGTH / 2.0),
            Color(0.12, 0.13, 0.15)
        )

        # Road shoulders
        _box(
            segment,
            Vector3(1.2, 0.27, ROAD_LENGTH),
            Vector3(-7.5, -0.15, -ROAD_LENGTH / 2.0),
            Color(0.75, 0.18, 0.10)
        )

        _box(
            segment,
            Vector3(1.2, 0.27, ROAD_LENGTH),
            Vector3(7.5, -0.15, -ROAD_LENGTH / 2.0),
            Color(0.75, 0.18, 0.10)
        )

        # Lane markings
        for line_index in range(6):
            var line_z := -5.0 - float(line_index) * 9.0

            _box(
                segment,
                Vector3(0.12, 0.025, 3.6),
                Vector3(-2.3, -0.035, line_z),
                Color(0.95, 0.95, 0.86)
            )

            _box(
                segment,
                Vector3(0.12, 0.025, 3.6),
                Vector3(2.3, -0.035, line_z),
                Color(0.95, 0.95, 0.86)
            )

        _create_buildings(segment)

        road_segments.append(segment)


func _create_buildings(segment: Node3D) -> void:
    var building_colors: Array[Color] = [
        Color(0.28, 0.34, 0.42),
        Color(0.38, 0.40, 0.43),
        Color(0.26, 0.30, 0.36),
        Color(0.48, 0.43, 0.38)
    ]

    for side_index in range(2):
        var side: float = -1.0 if side_index == 0 else 1.0
        for index in range(3):
            var building_height: float = randf_range(7.0, 17.0)
            var building_width: float = randf_range(4.0, 7.0)

            var building_z: float = -8.0 - float(index) * 19.0
            var random_offset: float = randf_range(12.0, 17.0)
            var building_x: float = side * random_offset

            _box(
                segment,
                Vector3(
                    building_width,
                    building_height,
                    randf_range(5.0, 9.0)
                ),
                Vector3(
                    building_x,
                    building_height / 2.0 - 0.25,
                    building_z
                ),
                building_colors[
                    randi_range(0, building_colors.size() - 1)
                ]
            )
            # Repeating glass strips catch the sunlight and make the skyline
            # read as modern city blocks rather than plain cubes.
            var facade_z: float = building_z - 0.2
            for floor_index in range(1, int(building_height / 2.5)):
                var window_y: float = float(floor_index) * 2.2
                _box(segment, Vector3(building_width * 0.72, 0.10, 0.035), Vector3(building_x, window_y, facade_z), Color(0.22, 0.42, 0.60), 0.35)


func _update_road(delta: float) -> void:
    for segment in road_segments:
        segment.position.z += speed * delta

        if segment.position.z > ROAD_LENGTH:
            segment.position.z -= ROAD_LENGTH * ROAD_SEGMENTS


# --------------------------------------------------
# PLAYER
# --------------------------------------------------

func _create_player() -> void:
    player_car = _create_car(
        self,
        Color(0.85, 0.055, 0.035),
        true
    )

    player_car.position = Vector3(0.0, 0.0, 0.0)


func _update_speed(delta: float) -> void:
    if braking:
        speed = maxf(12.0, speed - 42.0 * delta)
    else:
        speed = minf(MAX_SPEED, speed + 2.5 * delta)

    if nitro_active and nitro > 0.0:
        speed = minf(NITRO_SPEED, speed + 35.0 * delta)
        nitro = maxf(0.0, nitro - 32.0 * delta)
    else:
        nitro = minf(100.0, nitro + 7.0 * delta)


func _update_player(delta: float) -> void:
    var direction := 0.0

    if steering_left:
        direction -= 1.0

    if steering_right:
        direction += 1.0

    player_car.position.x += direction * STEER_SPEED * delta
    player_car.position.x = clampf(
        player_car.position.x,
        -ROAD_LIMIT,
        ROAD_LIMIT
    )

    # Steering animation
    player_car.rotation.z = lerpf(
        player_car.rotation.z,
        -direction * 0.10,
        minf(1.0, delta * 7.0)
    )


# --------------------------------------------------
# OPPONENTS
# --------------------------------------------------

func _create_opponents() -> void:
    var colors: Array[Color] = [
        Color(0.04, 0.36, 0.95),
        Color(0.95, 0.65, 0.04),
        Color(0.12, 0.78, 0.38),
        Color(0.60, 0.15, 0.85),
        Color(0.85, 0.85, 0.88)
    ]

    for index in range(5):
        var opponent := _create_car(
            self,
            colors[index],
            false
        )

        opponent.position = Vector3(
            _random_lane(),
            0.0,
            -45.0 - float(index) * 32.0
        )

        opponent_cars.append(opponent)


func _random_lane() -> float:
    var lanes: Array[float] = [-4.0, 0.0, 4.0]
    return lanes[randi_range(0, lanes.size() - 1)]


func _update_opponents(delta: float) -> void:
    for opponent in opponent_cars:
        opponent.position.z += speed * 0.78 * delta

        # Recycle cars after they pass the player.
        if opponent.position.z > 12.0:
            opponent.position.z = -randf_range(90.0, 190.0)
            opponent.position.x = _random_lane()

        # Basic arcade collision detection.
        var distance_z := absf(
            opponent.position.z - player_car.position.z
        )

        var distance_x := absf(
            opponent.position.x - player_car.position.x
        )

        if distance_z < 2.4 and distance_x < 1.65:
            _handle_collision()
            return


func _handle_collision() -> void:
    if crashed:
        return

    crashed = true
    if crash_audio:
        crash_audio.play()
    speed = 0.0
    steering_left = false
    steering_right = false
    braking = false
    nitro_active = false

    message_label.text = "CRASH!\nScore: %d" % int(score)
    message_label.visible = true
    restart_button.visible = true


# --------------------------------------------------
# CAMERA
# --------------------------------------------------

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.position = Vector3(0.0, 5.5, 9.0)
    camera.current = true
    camera.fov = 72.0
    add_child(camera)
    camera.look_at(Vector3(0.0, 1.0, -12.0), Vector3.UP)

    cockpit_camera = Camera3D.new()
    cockpit_camera.position = Vector3(0.0, 1.48, -0.36)
    cockpit_camera.fov = 82.0
    player_car.add_child(cockpit_camera)
    cockpit_camera.look_at(Vector3(0.0, 1.40, -35.0), Vector3.UP)

    # Dashboard, instrument hood and steering wheel are visible from the cockpit.
    _box(player_car, Vector3(1.24, 0.16, 0.42), Vector3(0.0, 1.03, -0.02), Color(0.025, 0.035, 0.045), 0.1)
    _box(player_car, Vector3(0.42, 0.08, 0.05), Vector3(0.0, 1.13, -0.12), Color(0.04, 0.72, 0.95), 0.3)
    var cockpit_wheel := MeshInstance3D.new()
    var wheel_mesh := TorusMesh.new()
    wheel_mesh.inner_radius = 0.19
    wheel_mesh.outer_radius = 0.24
    cockpit_wheel.mesh = wheel_mesh
    cockpit_wheel.position = Vector3(0.0, 1.05, -0.48)
    cockpit_wheel.rotation.x = deg_to_rad(68.0)
    cockpit_wheel.material_override = _material(Color(0.025, 0.03, 0.035), 0.15)
    player_car.add_child(cockpit_wheel)


func _update_camera(delta: float) -> void:
    if camera_mode == 1:
        cockpit_camera.current = true
        camera.current = false
        cockpit_camera.position.x = lerpf(cockpit_camera.position.x, player_car.rotation.z * 0.4, minf(1.0, delta * 5.0))
        cockpit_camera.fov = lerpf(cockpit_camera.fov, 82.0 if nitro_active and nitro > 0.0 else 76.0, minf(1.0, delta * 3.0))
        return

    camera.current = true
    cockpit_camera.current = false
    var target_position := Vector3(player_car.position.x * 0.55, 5.5, 9.0)
    camera.position = camera.position.lerp(target_position, minf(1.0, delta * 4.0))
    camera.look_at(Vector3(player_car.position.x * 0.35, 1.0, -12.0), Vector3.UP)
    var target_fov := 82.0 if nitro_active and nitro > 0.0 else 72.0
    camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 3.0))


func _toggle_camera() -> void:
    camera_mode = 1 - camera_mode
    camera.current = camera_mode == 0
    cockpit_camera.current = camera_mode == 1
    if camera_button:
        camera_button.text = "COCKPIT" if camera_mode == 0 else "CHASE CAM"


# --------------------------------------------------
# AUDIO (offline, bundled WAV files)
# --------------------------------------------------
func _create_audio() -> void:
    engine_audio = AudioStreamPlayer.new()
    var engine_stream: AudioStreamWAV = preload("res://assets/audio/engine.wav")
    engine_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    engine_audio.stream = engine_stream
    engine_audio.volume_db = -9.0
    add_child(engine_audio)
    engine_audio.play()

    brake_audio = AudioStreamPlayer.new()
    brake_audio.stream = preload("res://assets/audio/brake.wav")
    brake_audio.volume_db = -3.0
    add_child(brake_audio)

    nitro_audio = AudioStreamPlayer.new()
    var nitro_stream: AudioStreamWAV = preload("res://assets/audio/nitro.wav")
    nitro_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
    nitro_audio.stream = nitro_stream
    nitro_audio.volume_db = -7.0
    add_child(nitro_audio)

    crash_audio = AudioStreamPlayer.new()
    crash_audio.stream = preload("res://assets/audio/crash.wav")
    crash_audio.volume_db = -2.0
    add_child(crash_audio)


func _update_audio(_delta: float) -> void:
    if engine_audio and engine_audio.playing:
        if paused or crashed:
            engine_audio.volume_db = -80.0
        else:
            engine_audio.pitch_scale = clampf(0.72 + speed / MAX_SPEED * 0.85, 0.65, 1.8)
            engine_audio.volume_db = -12.0 + clampf(speed / MAX_SPEED, 0.0, 1.0) * 5.0
    if braking and not last_braking and brake_audio:
        brake_audio.play()
    last_braking = braking
    if (paused or crashed):
        if nitro_audio and nitro_audio.playing:
            nitro_audio.stop()
        return
    if nitro_active and nitro > 0.0:
        if nitro_audio and not nitro_audio.playing:
            nitro_audio.play()
    elif nitro_audio and nitro_audio.playing:
        nitro_audio.stop()


# --------------------------------------------------
# USER INTERFACE
# --------------------------------------------------

func _create_ui() -> void:
    ui_layer = CanvasLayer.new()
    add_child(ui_layer)

    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_layer.add_child(root)

    hud_label = _make_label(
        root,
        "VELOCITY RUSH",
        Vector2(25.0, 18.0),
        25
    )

    speed_label = _make_label(
        root,
        "SPEED 000",
        Vector2(25.0, 57.0),
        23
    )

    nitro_label = _make_label(
        root,
        "NITRO 100%",
        Vector2(25.0, 94.0),
        19
    )

    message_label = _make_label(
        root,
        "",
        Vector2(0.0, 0.0),
        34
    )

    message_label.set_anchors_and_offsets_preset(
        Control.PRESET_CENTER
    )

    message_label.position = Vector2(-230.0, -85.0)
    message_label.size = Vector2(460.0, 170.0)
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    message_label.visible = false

    # Left steering
    var left_button := _make_button(
        root,
        "◀",
        Vector4(0.0, 1.0, 0.0, 1.0),
        Vector4(25.0, -125.0, 125.0, -30.0)
    )

    left_button.button_down.connect(_on_left_down)
    left_button.button_up.connect(_on_left_up)

    # Right steering
    var right_button := _make_button(
        root,
        "▶",
        Vector4(0.0, 1.0, 0.0, 1.0),
        Vector4(140.0, -125.0, 240.0, -30.0)
    )

    right_button.button_down.connect(_on_right_down)
    right_button.button_up.connect(_on_right_up)

    # Brake
    var brake_button := _make_button(
        root,
        "BRAKE",
        Vector4(1.0, 1.0, 1.0, 1.0),
        Vector4(-290.0, -120.0, -160.0, -30.0)
    )

    brake_button.button_down.connect(_on_brake_down)
    brake_button.button_up.connect(_on_brake_up)

    # Nitro
    nitro_button = _make_button(
        root,
        "NITRO",
        Vector4(1.0, 1.0, 1.0, 1.0),
        Vector4(-150.0, -130.0, -25.0, -30.0)
    )

    nitro_button.button_down.connect(_on_nitro_down)
    nitro_button.button_up.connect(_on_nitro_up)

    # Pause
    pause_button = _make_button(
        root,
        "Ⅱ",
        Vector4(1.0, 0.0, 1.0, 0.0),
        Vector4(-100.0, 20.0, -20.0, 85.0)
    )

    pause_button.pressed.connect(_toggle_pause)

    camera_button = _make_button(
        root,
        "COCKPIT",
        Vector4(1.0, 0.0, 1.0, 0.0),
        Vector4(-245.0, 20.0, -115.0, 78.0)
    )
    camera_button.add_theme_font_size_override("font_size", 14)
    camera_button.pressed.connect(_toggle_camera)

    var wheel_mode_button := _make_button(
        root,
        "WHEEL",
        Vector4(1.0, 0.0, 1.0, 0.0),
        Vector4(-390.0, 20.0, -260.0, 78.0)
    )
    wheel_mode_button.add_theme_font_size_override("font_size", 15)
    wheel_mode_button.pressed.connect(_toggle_steering_mode)

    steering_wheel_control = Control.new()
    steering_wheel_control.anchor_left = 0.0
    steering_wheel_control.anchor_top = 1.0
    steering_wheel_control.anchor_right = 0.0
    steering_wheel_control.anchor_bottom = 1.0
    steering_wheel_control.offset_left = 24.0
    steering_wheel_control.offset_top = -210.0
    steering_wheel_control.offset_right = 205.0
    steering_wheel_control.offset_bottom = -20.0
    steering_wheel_control.mouse_filter = Control.MOUSE_FILTER_STOP
    steering_wheel_control.visible = false
    steering_wheel_control.gui_input.connect(_on_wheel_gui_input)
    root.add_child(steering_wheel_control)

    steering_wheel_label = Label.new()
    steering_wheel_label.text = "◉"
    steering_wheel_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    steering_wheel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    steering_wheel_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    steering_wheel_label.add_theme_font_size_override("font_size", 105)
    steering_wheel_label.add_theme_color_override("font_color", Color(0.78, 0.88, 0.98, 0.95))
    steering_wheel_control.add_child(steering_wheel_label)

    # Restart
    restart_button = _make_button(
        root,
        "RACE AGAIN",
        Vector4(0.5, 0.5, 0.5, 0.5),
        Vector4(-100.0, 95.0, 100.0, 155.0)
    )

    restart_button.pressed.connect(_restart_race)
    restart_button.visible = false


func _make_label(
    parent: Control,
    text_value: String,
    position_value: Vector2,
    font_size: int
) -> Label:
    var label := Label.new()

    label.text = text_value
    label.position = position_value
    label.size = Vector2(360.0, 38.0)

    label.add_theme_font_size_override(
        "font_size",
        font_size
    )

    label.add_theme_color_override(
        "font_color",
        Color(1.0, 1.0, 1.0)
    )

    label.add_theme_color_override(
        "font_shadow_color",
        Color(0.0, 0.0, 0.0, 0.8)
    )

    label.add_theme_constant_override("shadow_offset_x", 2)
    label.add_theme_constant_override("shadow_offset_y", 2)

    parent.add_child(label)
    return label


func _make_button(
    parent: Control,
    text_value: String,
    anchors: Vector4,
    offsets: Vector4
) -> Button:
    var button := Button.new()

    button.text = text_value

    button.anchor_left = anchors.x
    button.anchor_top = anchors.y
    button.anchor_right = anchors.z
    button.anchor_bottom = anchors.w

    button.offset_left = offsets.x
    button.offset_top = offsets.y
    button.offset_right = offsets.z
    button.offset_bottom = offsets.w

    button.focus_mode = Control.FOCUS_NONE

    button.add_theme_font_size_override(
        "font_size",
        20
    )

    button.add_theme_color_override(
        "font_color",
        Color.WHITE
    )

    var normal_style := StyleBoxFlat.new()
    normal_style.bg_color = Color(0.04, 0.10, 0.18, 0.88)
    normal_style.corner_radius_top_left = 15
    normal_style.corner_radius_top_right = 15
    normal_style.corner_radius_bottom_left = 15
    normal_style.corner_radius_bottom_right = 15
    normal_style.border_width_left = 2
    normal_style.border_width_right = 2
    normal_style.border_width_top = 2
    normal_style.border_width_bottom = 2
    normal_style.border_color = Color(0.12, 0.65, 1.0)

    var hover_style := normal_style.duplicate() as StyleBoxFlat
    hover_style.bg_color = Color(0.08, 0.22, 0.36, 0.96)

    var pressed_style := normal_style.duplicate() as StyleBoxFlat
    pressed_style.bg_color = Color(0.05, 0.50, 0.90, 0.98)

    button.add_theme_stylebox_override("normal", normal_style)
    button.add_theme_stylebox_override("hover", hover_style)
    button.add_theme_stylebox_override("pressed", pressed_style)
    button.add_theme_stylebox_override("focus", normal_style)

    parent.add_child(button)
    return button


# --------------------------------------------------
# BUTTON CALLBACKS
# --------------------------------------------------
func _toggle_steering_mode() -> void:
    var use_wheel: bool = not steering_wheel_control.visible
    steering_wheel_control.visible = use_wheel
    for child in ui_layer.get_children():
        if child is Control:
            for item in child.get_children():
                if item is Button and (item.text == "◀" or item.text == "▶"):
                    item.visible = not use_wheel


func _on_wheel_gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        wheel_dragging = event.pressed
        if not event.pressed:
            steering_left = false
            steering_right = false
    elif event is InputEventScreenDrag and wheel_dragging:
        var local_x: float = event.position.x
        var center_x: float = steering_wheel_control.size.x * 0.5
        steering_left = local_x < center_x - 12.0
        steering_right = local_x > center_x + 12.0


func _on_left_down() -> void:
    steering_left = true


func _on_left_up() -> void:
    steering_left = false


func _on_right_down() -> void:
    steering_right = true


func _on_right_up() -> void:
    steering_right = false


func _on_brake_down() -> void:
    braking = true


func _on_brake_up() -> void:
    braking = false


func _on_nitro_down() -> void:
    nitro_active = true


func _on_nitro_up() -> void:
    nitro_active = false


func _toggle_pause() -> void:
    if crashed:
        return

    paused = not paused

    if paused:
        message_label.text = "PAUSED"
        message_label.visible = true
        pause_button.text = "▶"
    else:
        message_label.visible = false
        pause_button.text = "Ⅱ"


func _restart_race() -> void:
    crashed = false
    paused = false

    speed = 28.0
    score = 0.0
    nitro = 100.0

    steering_left = false
    steering_right = false
    braking = false
    nitro_active = false

    player_car.position = Vector3.ZERO
    player_car.rotation = Vector3.ZERO
    camera_mode = 0
    camera.current = true
    cockpit_camera.current = false
    camera_button.text = "COCKPIT"

    for index in range(opponent_cars.size()):
        opponent_cars[index].position = Vector3(
            _random_lane(),
            0.0,
            -55.0 - float(index) * 35.0
        )

    message_label.visible = false
    restart_button.visible = false
    pause_button.text = "Ⅱ"

    _update_hud()


# --------------------------------------------------
# HUD AND SCORE
# --------------------------------------------------

func _update_score(delta: float) -> void:
    score += speed * delta * 0.12


func _update_hud() -> void:
    speed_label.text = "SPEED  %03d KM/H" % int(speed * 4.0)
    nitro_label.text = "NITRO  %d%%" % int(nitro)

    hud_label.text = "VELOCITY RUSH  |  SCORE %06d" % int(score)

    if nitro <= 0.0:
        nitro_button.modulate = Color(0.6, 0.6, 0.6)
    else:
        nitro_button.modulate = Color.WHITE
