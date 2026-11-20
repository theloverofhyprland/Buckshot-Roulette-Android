"""Fail the build if the packed game cannot resolve its imported resources.

The exported engine needs <source>.remap next to every imported asset and every
remap target must exist in .godot/. Textures must be ETC2 (works on Mali,
Xclipse and Adreno GLES3).
"""
import os, re, struct, sys

game = sys.argv[1]
problems = []
warnings = []
imports = remaps = ctex = 0
imported = {}  # source path -> remap target

for root, dirs, files in os.walk(game):
    dirs[:] = [d for d in dirs if d != 'tools']
    for f in files:
        p = os.path.join(root, f)
        rel = os.path.relpath(p, game).replace(os.sep, '/')
        if f.endswith('.import'):
            imports += 1
            text = open(p, encoding='utf-8', errors='replace').read()
            if not re.search(r'^path(?:\.[a-z0-9]+)?="res://', text, re.M):
                continue  # csv translations are referenced by project settings
            src = rel[:-len('.import')]
            if not os.path.exists(p[:-len('.import')] + '.remap'):
                problems.append(f'{rel}: imported but has no .remap')
            for key, value in re.findall(r'^(path(?:\.[a-z0-9]+)?)="(res://[^"]+)"', text, re.M):
                if os.path.exists(os.path.join(game, value[6:])):
                    imported[src] = value
                    break
        elif f.endswith('.remap'):
            remaps += 1
            text = open(p, encoding='utf-8', errors='replace').read()
            m = re.search(r'^path="res://([^"]+)"', text, re.M)
            if not m:
                problems.append(f'{rel}: no path')
            elif not os.path.exists(os.path.join(game, m.group(1))):
                problems.append(f'{rel}: target missing {m.group(1)}')

ig = os.path.join(game, '.godot/imported')
for root, dirs, files in os.walk(ig):
    for f in files:
        if not f.endswith('.ctex'):
            continue
        p = os.path.join(root, f)
        with open(p, 'rb') as fh:
            h = fh.read(52)
        if len(h) < 52 or h[:4] != b'GST2':
            problems.append(f'{f}: bad ctex header')
            continue
        inner = struct.unpack_from('<I', h, 36)[0]
        fmt = struct.unpack_from('<I', h, 48)[0]
        ctex += 1
        if inner == 0 and fmt not in range(25, 34):
            problems.append(f'{f}: format {fmt} is not ETC2')
        elif inner not in (0, 1, 2, 3):
            problems.append(f'{f}: unexpected data format {inner}')

# Every res:// reference with an imported extension must resolve through a remap.
exts = sorted({os.path.splitext(s)[1].lstrip('.').lower() for s in imported})
ref_re = re.compile(rb'res://[^\x00-\x1f"\\]{1,200}?\.(?:' + b'|'.join(e.encode() for e in exts) + rb')(?![a-z0-9])')
seen = set()
for root, dirs, files in os.walk(game):
    dirs[:] = [d for d in dirs if d != 'tools']
    for f in files:
        if not f.endswith(('.scn', '.res', '.tscn', '.tres', '.gd')):
            continue
        p = os.path.join(root, f)
        data = open(p, 'rb').read()
        for m in ref_re.finditer(data):
            ref = m.group(0).decode('utf-8', 'replace')
            if ref in seen:
                continue
            seen.add(ref)
            src = ref[6:]
            if os.path.exists(os.path.join(game, src)):
                continue
            if not os.path.exists(os.path.join(game, src + '.remap')):
                warnings.append(f'{os.path.relpath(p, game)}: unresolved {ref}')

print(f'imports={imports} remaps={remaps} ctex_etc2={ctex} refs={len(seen)}')
for w in warnings[:20]:
    print('WARN', w)
if len(warnings) > 20:
    print(f'WARN ... and {len(warnings) - 20} more')
for pr in problems[:20]:
    print('FAIL', pr)
if len(problems) > 20:
    print(f'FAIL ... and {len(problems) - 20} more')
sys.exit(1 if problems else 0)
