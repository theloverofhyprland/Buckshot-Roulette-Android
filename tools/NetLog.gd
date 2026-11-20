extends Node

# Diagnostics for the Android port: sends the game's own logcat and boot info
# to a TCP listener on the device (127.0.0.1:29099) and paints a green bar so a
# screenshot shows whether rendering came up at all.

const HOST := "127.0.0.1"
const PORT := 29099

var tcp := StreamPeerTCP.new()
var connected := false
var pending := PackedStringArray()
var seen := {}
var dump_timer := 0.0
var last_scene := ""

func _ready():
	var vi := Engine.get_version_info()
	send("NetLog start engine=%s model=%s os=%s" % [vi["string"], OS.get_model_name(), OS.get_version()])
	send("renderer=%s adapter=%s vendor=%s api=%s" % [
		str(ProjectSettings.get_setting("rendering/renderer/rendering_method")),
		RenderingServer.get_video_adapter_name(),
		RenderingServer.get_video_adapter_vendor(),
		RenderingServer.get_video_adapter_api_version()])
	send("window=%s main_scene=%s" % [
		str(DisplayServer.window_get_size()),
		str(ProjectSettings.get_setting("application/run/main_scene"))])
	call_deferred("_make_overlay")
	dump_logcat()
	set_process(true)

func _make_overlay():
	var cl := CanvasLayer.new()
	cl.layer = 128
	var bar := ColorRect.new()
	bar.color = Color(0.0, 0.55, 0.0, 0.95)
	bar.position = Vector2.ZERO
	bar.size = Vector2(DisplayServer.window_get_size().x, 44)
	var lbl := Label.new()
	lbl.text = " NetLog OK: " + RenderingServer.get_video_adapter_name()
	lbl.position = Vector2(12, 6)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	cl.add_child(bar)
	cl.add_child(lbl)
	get_tree().root.add_child(cl)

func _process(delta):
	var st := tcp.get_status()
	if not connected:
		if st == StreamPeerTCP.STATUS_NONE or st == StreamPeerTCP.STATUS_ERROR:
			tcp = StreamPeerTCP.new()
			tcp.connect_to_host(HOST, PORT)
		elif st == StreamPeerTCP.STATUS_CONNECTING:
			tcp.poll()
		elif st == StreamPeerTCP.STATUS_CONNECTED:
			connected = true
			_flush()
		return
	_flush()
	dump_timer += delta
	if dump_timer >= 0.5:
		dump_timer = 0.0
		dump_logcat()
	var sc := ""
	if get_tree().current_scene != null:
		sc = str(get_tree().current_scene.name)
	if sc != last_scene:
		last_scene = sc
		send("current_scene=" + sc)

func send(line: String):
	pending.append(line)
	if connected:
		_flush()

func _flush():
	while pending.size() > 0:
		var s: String = pending[0] + "\n"
		if tcp.put_data(s.to_utf8_buffer()) != OK:
			connected = false
			return
		pending.remove_at(0)

func dump_logcat():
	var out := []
	var code := OS.execute("/system/bin/logcat", ["-d", "-v", "brief", "-t", "300"], out, true)
	if code != 0 or out.is_empty():
		return
	var text: String = out[0]
	for line in text.split("\n"):
		if line == "":
			continue
		var low := line.to_lower()
		if low.find("godot") < 0 and low.find("egl") < 0 and low.find("mali") < 0 \
				and low.find("gralloc") < 0 and low.find("vulkan") < 0 \
				and low.find("crash") < 0 and low.find("fatal") < 0 \
				and low.find("error") < 0 and low.find("shader") < 0:
			continue
		if seen.has(line):
			continue
		seen[line] = true
		send("[logcat] " + line)
