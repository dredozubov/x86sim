#!/usr/bin/env python3
"""x86Sim sdkcov: how much of an SDK's public API the checks reach, per framework. Public types = ObjC @interface
declarations in each framework's Headers/*.h plus top-level public Swift types in its .swiftinterface; a type counts
as referenced when its name appears in the app's sources (checks/, *.swift, objc/, ext/). A name-level measure:
it does not know #if platform guards, and it reads header comments too.
Usage: tests/apps/sdkcov/apisurf.py <ios|tvos|watchos|xros> [N]   (N: how many frameworks to list, most missing first)
Writes the per-framework misses to $X86SIM_SCRATCH/sdkcov-apisurf-<platform>.json."""
# per-framework public API names (ObjC classes from tbd + Swift public types from swiftinterface) not referenced in sdkcov sources
import glob,json,os,re,sys
os.chdir(os.environ.get('SDKCOV_DIR',os.path.dirname(os.path.realpath(__file__))))
plat=sys.argv[1]; sdk={'ios':'iPhoneSimulator','tvos':'AppleTVSimulator','watchos':'WatchSimulator-xcode','xros':'XRSimulator-xcode'}[plat]
S=os.path.realpath(os.path.join(os.getcwd(),'../../../sdks',f'{sdk}.sdk/System/Library/Frameworks'))
src=''
for f in glob.glob('checks/*.swift')+glob.glob('*.swift')+glob.glob('objc/**/*',recursive=True)+glob.glob('ext/**/*.swift',recursive=True):
    if os.path.isfile(f): src+=open(f,errors='replace').read()
words=set(re.findall(r'[A-Za-z_][A-Za-z0-9_]*',src))
out=[]
for fw in sorted(glob.glob(S+'/*.framework')):
    n=os.path.basename(fw)[:-10]
    if n.startswith('_'): continue
    names=set()
    for h in glob.glob(fw+'/Headers/*.h'):
        txt=open(h,errors='replace').read()
        names|=set(re.findall(r'^@interface\s+([A-Za-z][A-Za-z0-9]*)\s*:',txt,re.M))
    for t in []:
        txt=open(t,errors='replace').read()
        names|=set(re.findall(r'_OBJC_CLASS_\$_([A-Za-z][A-Za-z0-9]*)',txt))
        for m in re.findall(r'objc-classes:\s*\[([^\]]*)\]',txt): names|=set(re.findall(r'[A-Za-z][A-Za-z0-9]*',m))
        try:
            d=json.loads(txt)
            for e in d['main_library'].get('exported_symbols',[]):
                for v in e.values():
                    if isinstance(v,dict): names|=set(v.get('objc_class',[]))
        except Exception: pass
    for si in glob.glob(fw+'/Modules/*.swiftmodule/*arm64*.swiftinterface'):
        if 'private' in si: continue
        names|=set(re.findall(r'^(?:@\S+\s+)*public\s+(?:final\s+)?(?:class|struct|enum|actor|protocol)\s+([A-Za-z][A-Za-z0-9]*)',open(si,errors='replace').read(),re.M))
    names={x for x in names if not x.startswith('_') and len(x)>3}
    if not names: continue
    miss=sorted(names-words)
    out.append((n,len(names),len(names)-len(miss),miss))
out.sort(key=lambda r:-len(r[3]))
tot=sum(r[1] for r in out); hit=sum(r[2] for r in out)
print(f'{plat}: {hit}/{tot} public types referenced')
for n,t,h,m in out[:int(sys.argv[2]) if len(sys.argv)>2 else 40]:
    print(f'{n:28} {h:4}/{t:<4} e.g. {" ".join(m[:8])}')
json.dump({r[0]:{'total':r[1],'hit':r[2],'miss':r[3]} for r in out},open(os.path.join(os.environ.get('X86SIM_SCRATCH',os.path.expanduser('~/scratch')),f'sdkcov-apisurf-{plat}.json'),'w'),indent=0)
