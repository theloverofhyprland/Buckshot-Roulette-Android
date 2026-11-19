extends SceneTree

# BC1/BC3/BPTC -> ETC2, in place. ETC2 is required by GLES3 and supported by
# Mali, Xclipse and Adreno alike, so the same APK works everywhere.
const COMPRESSED := [17, 18, 19, 22, 23, 24]
var converted := 0
var skipped := 0
var failed := 0

func _init():
	walk("res://")
	print("CONVERT_DONE converted=", converted, " skipped=", skipped, " failed=", failed)
	quit(0)

func walk(path: String):
	var d := DirAccess.open(path)
	if d == null: return
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		var p := path.path_join(n)
		if d.current_is_dir():
			walk(p)
		elif n.ends_with(".ctex"):
			convert_one(p)
		n = d.get_next()
	d.list_dir_end()

func convert_one(p: String):
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		failed += 1; return
	var head := f.get_buffer(36)
	if head.size() < 36 or head[0] != 71:
		failed += 1; return
	var df := f.get_32()
	var w := f.get_16()
	var h := f.get_16()
	var mips := f.get_32()
	var fmt := f.get_32()
	if df != 0 or not (fmt in COMPRESSED):
		skipped += 1; f.close(); return
	var data := f.get_buffer(f.get_length() - f.get_position())
	f.close()
	var img := Image.create_from_data(w, h, mips > 0, fmt, data)
	if img == null or img.is_empty():
		failed += 1; print("FAIL create ", p); return
	var err := img.decompress()
	if err != OK or img.is_compressed():
		failed += 1; print("FAIL decompress ", p, " err=", err); return
	img.convert(Image.FORMAT_RGBA8)
	err = img.compress(Image.COMPRESS_ETC2)
	if err != OK or not img.is_compressed():
		failed += 1; print("FAIL compress ", p, " err=", err); return
	var nf := FileAccess.open(p, FileAccess.WRITE)
	if nf == null:
		failed += 1; return
	nf.store_buffer(head)
	nf.store_32(0)
	nf.store_16(img.get_width())
	nf.store_16(img.get_height())
	nf.store_32(img.get_mipmap_count())
	nf.store_32(img.get_format())
	nf.store_buffer(img.get_data())
	nf.close()
	converted += 1
	if converted % 50 == 0: print("converted ", converted)
