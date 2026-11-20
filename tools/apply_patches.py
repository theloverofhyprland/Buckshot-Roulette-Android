import os, re, sys, struct
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import ecfg

game = sys.argv[1]
renderer = sys.argv[2] if len(sys.argv) > 2 else "gl_compatibility"

# ---- project.binary (raw-preserving patch) ----
def parse_raw(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'ECFG', d[:4]
    n = struct.unpack_from('<I', d, 4)[0]
    p = 8
    items = []
    for _ in range(n):
        kl = struct.unpack_from('<I', d, p)[0]; p += 4
        k = d[p:p+kl].decode(); p += kl
        vl = struct.unpack_from('<I', d, p)[0]; p += 4
        items.append((k, d[p:p+vl])); p += vl
    assert p == len(d), (p, len(d))
    return items

def set_raw(items, key, value):
    raw = ecfg.enc(value)
    for i, (k, _) in enumerate(items):
        if k == key:
            items[i] = (key, raw)
            return
    items.append((key, raw))

def save_raw(path, items):
    b = bytearray(b'ECFG') + struct.pack('<I', len(items))
    for k, raw in items:
        kb = k.encode()
        b += struct.pack('<I', len(kb)) + kb + struct.pack('<I', len(raw)) + raw
    open(path, 'wb').write(b)

pb = os.path.join(game, 'project.binary')
items = parse_raw(pb)
set_raw(items, 'rendering/renderer/rendering_method', renderer)
set_raw(items, 'rendering/renderer/rendering_method.mobile', renderer)
set_raw(items, 'display/window/handheld/orientation', 0)
set_raw(items, 'input_devices/pointing/emulate_mouse_from_touch', True)
set_raw(items, 'input_devices/pointing/emulate_touch_from_mouse', False)
set_raw(items, 'autoload/TouchOverlay', '*res://scripts/TouchOverlay.gd')
set_raw(items, 'input_devices/pointing/android/enable_long_press_as_right_click', True)
save_raw(pb, items)
print('project.binary patched:', len(items), 'settings')

# ---- scripts ----
stub = open(os.path.join(os.path.dirname(__file__), 'Steam_stub.gd'), encoding='utf-8').read()
open(os.path.join(game, 'scripts/Steam.gd'), 'w', encoding='utf-8').write(stub)
touch = open(os.path.join(os.path.dirname(__file__), 'TouchOverlay.gd'), encoding='utf-8').read()
open(os.path.join(game, 'scripts/TouchOverlay.gd'), 'w', encoding='utf-8').write(touch)

changed = 0
leftover = []
pat = re.compile(r'\bSteam\.')
for root, dirs, files in os.walk(game):
    dirs[:] = [d for d in dirs if d != 'tools']
    for f in files:
        if not f.endswith('.gd'): continue
        p = os.path.join(root, f)
        if os.path.normpath(p) == os.path.normpath(os.path.join(game, 'scripts/Steam.gd')): continue
        t = open(p, encoding='utf-8', errors='replace').read()
        nt = pat.sub('GlobalSteam.', t)
        if nt != t:
            open(p, 'w', encoding='utf-8').write(nt); changed += 1
        if re.search(r'(?<!Global)\bSteam\b', nt):
            leftover.append(os.path.relpath(p, game))

gv = os.path.join(game, 'scripts/GlobalVariables.gd')
t = open(gv, encoding='utf-8').read()
t2 = re.sub(r'var using_steam\s*=\s*true', 'var using_steam = false', t)
assert t2 != t, 'using_steam not patched'
open(gv, 'w', encoding='utf-8').write(t2)
print(f'scripts rewritten: {changed}; Steam leftovers: {leftover}')

# ---- slim: replace MP music/audio (>200 KB) with the smallest valid stream ----
imp = os.path.join(game, '.godot/imported')
streams = []
for f in os.listdir(imp):
    if f.endswith('.oggvorbisstr'):
        p = os.path.join(imp, f)
        streams.append((os.path.getsize(p), p))
streams.sort()
if streams and os.environ.get('SLIM', '1') == '1':
    tiny = open(streams[0][1], 'rb').read()
    saved = 0
    for size, p in streams:
        if size > 150_000:
            saved += size - len(tiny)
            open(p, 'wb').write(tiny)
    print(f'Music/audio slimmed: {saved/1048576:.1f} MB')
