import struct,sys

T_NIL,T_BOOL,T_INT,T_FLOAT,T_STRING,T_V2,T_V2I,T_RECT2,T_RECT2I,T_V3,T_V3I,T_TR2,T_V4,T_V4I,T_PLANE,T_QUAT,T_AABB,T_BASIS,T_TR3,T_PROJ,T_COLOR,T_SNAME,T_NPATH,T_RID,T_OBJECT,T_CALLABLE,T_SIGNAL,T_DICT,T_ARRAY=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28
T_PBYTE,T_PI32,T_PI64,T_PF32,T_PF64,T_PSTR,T_PV2,T_PV3,T_PC4=29,30,31,32,33,34,35,36,37
F64=1<<16

class R:
    def __init__(s,b): s.b=b; s.p=0
    def u32(s):
        v=struct.unpack_from('<I',s.b,s.p)[0]; s.p+=4; return v
    def i32(s):
        v=struct.unpack_from('<i',s.b,s.p)[0]; s.p+=4; return v
    def i64(s):
        v=struct.unpack_from('<q',s.b,s.p)[0]; s.p+=8; return v
    def f32(s):
        v=struct.unpack_from('<f',s.b,s.p)[0]; s.p+=4; return v
    def f64(s):
        v=struct.unpack_from('<d',s.b,s.p)[0]; s.p+=8; return v
    def raw(s,n):
        v=s.b[s.p:s.p+n]; s.p+=n; return v
    def string(s):
        n=s.u32(); pad=(4-n%4)%4; v=s.raw(n).decode('utf-8','replace'); s.raw(pad); return v

def dec(r):
    t=r.u32(); base=t&0xff; f=t&~0xff
    if base==T_NIL: return None
    if base==T_BOOL: return bool(r.u32())
    if base==T_INT: return r.i64() if f&F64 else r.i32()
    if base==T_FLOAT: return r.f64() if f&F64 else r.f32()
    if base in (T_STRING,T_SNAME): return r.string()
    if base in (T_V2,T_RECT2,T_V3,T_TR2,T_V4,T_PLANE,T_QUAT,T_AABB,T_BASIS,T_TR3,T_PROJ,T_COLOR):
        n={T_V2:2,T_RECT2:4,T_V3:3,T_TR2:6,T_V4:4,T_PLANE:4,T_QUAT:4,T_AABB:6,T_BASIS:9,T_TR3:12,T_PROJ:16,T_COLOR:4}[base]
        v=[r.f64() if f&F64 else r.f32() for _ in range(n)]; return v
    if base in (T_V2I,T_RECT2I,T_V3I,T_V4I):
        n={T_V2I:2,T_RECT2I:4,T_V3I:3,T_V4I:4}[base]
        return [r.i32() for _ in range(n)]
    if base==T_NPATH: return r.string()
    if base==T_OBJECT:
        n=r.u32()
        if n&0x80000000: n&=0x7fffffff; r.raw(8*n)  # ids
        else: r.raw(n)  # heuristic: class string? not needed
        return {'__obj__':n}
    if base==T_DICT:
        n=r.u32()&0x7fffffff; d={}
        for _ in range(n):
            k=dec(r); v=dec(r); d[k if isinstance(k,(str,int,float,bool)) or k is None else str(k)]=v
        return d
    if base==T_ARRAY:
        n=r.u32()&0x7fffffff; return [dec(r) for _ in range(n)]
    if base==T_PBYTE:
        n=r.u32(); v=r.raw(n); r.raw((4-n%4)%4); return list(v)
    if base==T_PI32:
        n=r.u32(); return [r.i32() for _ in range(n)]
    if base==T_PI64:
        n=r.u32(); return [r.i64() for _ in range(n)]
    if base==T_PF32:
        n=r.u32(); return [r.f32() for _ in range(n)]
    if base==T_PF64:
        n=r.u32(); return [r.f64() for _ in range(n)]
    if base==T_PSTR:
        n=r.u32(); return [r.string() for _ in range(n)]
    if base==T_COLOR:
        v=list(struct.unpack_from('<4f',r.b,r.p)); r.p+=16; return v
    raise ValueError(f'type {base} at {r.p-4} flags {f}')

def enc(v):
    b=bytearray()
    def w(x): b.extend(x)
    if v is None: return struct.pack('<I',T_NIL)
    if isinstance(v,bool): return struct.pack('<II',T_BOOL,1 if v else 0)
    if isinstance(v,int):
        if -2**31<=v<2**31: return struct.pack('<Ii',T_INT,v)
        return struct.pack('<Iq',T_INT|F64,v)
    if isinstance(v,float):
        f=struct.unpack('<f',struct.pack('<f',v))[0]
        if f==v: return struct.pack('<If',T_FLOAT,f)
        return struct.pack('<Id',T_FLOAT|F64,v)
    if isinstance(v,str):
        u=v.encode(); pad=(4-len(u)%4)%4
        return struct.pack('<II',T_STRING,len(u))+u+b'\0'*pad
    if isinstance(v,list):
        if v and all(isinstance(x,int) and 0<=x<256 for x in v) and len(v)>8:
            return struct.pack('<II',T_PBYTE,len(v))+bytes(v)+b'\0'*((4-len(v)%4)%4)
        out=struct.pack('<II',T_ARRAY,len(v))
        return out+b''.join(enc(x) for x in v)
    if isinstance(v,dict):
        out=struct.pack('<II',T_DICT,len(v))
        for k,x in v.items(): out+=enc(k)+enc(x)
        return out
    raise TypeError(type(v))

def load(path):
    d=open(path,'rb').read()
    assert d[:4]==b'ECFG',d[:4]
    r=R(d); r.p=4; n=r.u32(); out=[]
    for _ in range(n):
        n=r.u32(); k=r.raw(n).decode(); ln=r.u32(); v=dec(R(d[r.p:r.p+ln])); r.p+=ln
        out.append((k,v))
    return out

def save(path,items):
    b=bytearray(b'ECFG')+struct.pack('<I',len(items))
    for k,v in items:
        u=k.encode(); b+=struct.pack('<I',len(u))+u
        vb=enc(v); b+=struct.pack('<I',len(vb))+vb
    open(path,'wb').write(b)

if __name__=='__main__':
    items=load(sys.argv[1])
    for k,v in items:
        s=repr(v)
        print(k,'=',s if len(s)<220 else s[:220]+'...')
