import os, sys, zipfile

template, assets, out = sys.argv[1], sys.argv[2], sys.argv[3]
skip_top = {'tools'}

def walk(base):
    for root, dirs, files in os.walk(base):
        dirs[:] = [d for d in dirs if d != '.git']
        for f in files:
            p = os.path.join(root, f)
            rel = os.path.relpath(p, base)
            if rel.split(os.sep)[0] in skip_top:
                continue
            yield p, rel.replace(os.sep, '/')

n = 0
total = 0
with zipfile.ZipFile(template) as zin, zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zout:
    for info in zin.infolist():
        name = info.filename
        if name.startswith('META-INF/') and (name.endswith('.RSA') or name.endswith('.SF') or name.endswith('.MF')):
            continue
        if name.startswith('lib/x86/'):
            continue
        if name.startswith('lib/x86_64/'):
            continue
        data = zin.read(name)
        zi = zipfile.ZipInfo(name, date_time=info.date_time)
        zi.compress_type = info.compress_type
        zi.external_attr = info.external_attr
        zout.writestr(zi, data)
    for p, rel in walk(assets):
        data = open(p, 'rb').read()
        zi = zipfile.ZipInfo('assets/' + rel, date_time=(2024, 1, 1, 0, 0, 0))
        zi.compress_type = zipfile.ZIP_DEFLATED
        zout.writestr(zi, data)
        n += 1
        total += len(data)
print(f'APK written: {out}; assets={n} files, {total/1048576:.1f} MB raw')
