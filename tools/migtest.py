"""Headless upgrade test: build state on an old mod version, save, load with the new version, inspect.
Usage: migtest.py <old mod dir> <new mod dir> <lab dir>"""
import json, pathlib, shutil, socket, struct, subprocess, sys, time
sys.stdout.reconfigure(encoding='utf-8')
OLD, NEW, LAB = (pathlib.Path(a) for a in sys.argv[1:4])
GAME = pathlib.Path(r'C:/Program Files (x86)/Steam/steamapps/common/Factorio'); EXE = GAME / 'bin/x64/factorio.exe'
RCON, PW = 27098, 'tardis-mig-test'


class Rcon:
    def __init__(self):
        self.s = socket.create_connection(('127.0.0.1', RCON), timeout=60); self.i = 0
        self.send(3, PW)
        while self.recv()[1] != 2: pass
    def send(self, k, v):
        self.i += 1; b = struct.pack('<ii', self.i, k) + v.encode() + b'\0\0'
        self.s.sendall(struct.pack('<i', len(b)) + b); return self.i
    def exact(self, n):
        b = b''
        while len(b) < n:
            x = self.s.recv(n - len(b))
            if not x: raise ConnectionError('closed')
            b += x
        return b
    def recv(self):
        n = struct.unpack('<i', self.exact(4))[0]; b = self.exact(n); i, k = struct.unpack('<ii', b[:8])
        return i, k, b[8:-2].decode('utf-8', 'replace')
    def lua(self, code, ctx='__tardis__ '):
        i = self.send(2, '/silent-command ' + ctx + code)
        while True:
            j, k, v = self.recv()
            if j == i: return v.strip()
    def cmd(self, c):
        i = self.send(2, c)
        while True:
            j, k, v = self.recv()
            if j == i: return v.strip()


def install(src):
    target = LAB / 'mods/tardis'
    if target.exists(): shutil.rmtree(target)
    shutil.copytree(src, target, ignore=shutil.ignore_patterns('.git*', '*.py', 'stylua.toml', 'art'))


def server(save):
    proc = subprocess.Popen([str(EXE), '--config', str(LAB / 'config.ini'), '--mod-directory', str(LAB / 'mods'),
                             '--start-server', str(save), '--rcon-port', str(RCON), '--rcon-password', PW,
                             '--server-settings', str(LAB / 'server-settings.json')],
                            stdout=open(LAB / 'server.log', 'a', encoding='utf-8'), stderr=subprocess.STDOUT)
    deadline = time.time() + 120
    while True:
        try:
            r = Rcon(); r.cmd('/silent-command rcon.print(1)'); r.cmd('/silent-command rcon.print(1)'); return proc, r
        except OSError:
            if proc.poll() is not None: raise RuntimeError('server exited: ' + (LAB / 'server.log').read_text(encoding='utf-8', errors='replace')[-3000:])
            if time.time() > deadline: raise
            time.sleep(1)


if LAB.exists(): shutil.rmtree(LAB)
(LAB / 'mods').mkdir(parents=True)
(LAB / 'mods/mod-list.json').write_text(json.dumps({'mods': [{'name': n, 'enabled': True} for n in
                                                            ['base', 'elevated-rails', 'quality', 'space-age', 'tardis']]}))
(LAB / 'config.ini').write_text(f'[path]\nread-data={GAME / "data"}\nwrite-data={LAB}\n[other]\ncheck-updates=false\n', encoding='utf-8')
settings = json.loads((GAME / 'data/server-settings.example.json').read_text())
settings.update({'visibility': {'public': False, 'lan': False}, 'auto_pause': False, 'autosave_interval': 0})
(LAB / 'server-settings.json').write_text(json.dumps(settings))
save = LAB / 'mig.zip'
install(OLD)
subprocess.run([str(EXE), '--config', str(LAB / 'config.ini'), '--mod-directory', str(LAB / 'mods'), '--create', str(save)],
               check=True, capture_output=True)
proc, r = server(save)
try:
    print('setup:', r.lua(
        "local s=game.surfaces.nauvis s.request_to_generate_chunks({0,0},2) s.force_generate_chunk_requests() "
        "local box=s.create_entity{name='tardis',position={0,0},force='player'} local id=Twelve.create(box) local f=Twelve.get(id) "
        "f.rooms[1]={kind='library',state='ready',entities={}} Twelve.Interior.room(f,1,f.rooms[1],false) "
        "local n=0 for _,e in pairs(f.rooms[1].entities) do if e.valid and e.name=='tardis-archive-cabinet' then n=n+1 e.insert{name='iron-plate',count=100} end end "
        "local esc=game.create_inventory(10) esc.insert{name='wood',count=150} "
        "f.rooms[2]={kind='library',state='building',escrow=esc,started=game.tick,finish=game.tick+10^7} "
        "rcon.print('cabinets='..n..' iron='..f.cargo.get_item_count('iron-plate')..' wood='..f.cargo.get_item_count('wood'))"))
    print(r.cmd('/server-save'))
    time.sleep(3)
finally:
    proc.kill(); time.sleep(2)
install(NEW)
proc, r = server(save)
try:
    time.sleep(4)
    print('after:', r.lua(
        "local f for _,v in pairs(storage.twelve.ships) do f=v end local t={} "
        "for k,v in pairs(f.rooms) do t[#t+1]=k..':'..v.kind..':'..v.state end "
        "rcon.print(table.concat(t,' ')..' cabinets='..f.surface.count_entities_filtered{name='tardis-archive-cabinet'}"
        "..' iron='..f.cargo.get_item_count('iron-plate')..' wood='..f.cargo.get_item_count('wood')"
        "..' archive='..tostring(f.blueprints and f.blueprints.valid and #f.blueprints))"))
    print('archive:', r.lua(
        "local f for _,v in pairs(storage.twelve.ships) do f=v end local B=Twelve.Blueprints "
        "local hand=game.create_inventory(1) local p={cursor_stack=hand[1]} local out={} "
        "hand[1].set_stack{name='blueprint'} hand[1].set_blueprint_entities{{entity_number=1,name='small-lamp',position={0.5,0.5}}} hand[1].label='Lamp test' "
        "local ok,m=B.store(p,f,5) out[#out+1]=tostring(ok)..':'..serpent.line(m) "
        "out[#out+1]='slot5='..tostring(f.blueprints[5].valid_for_read)..' hand='..tostring(hand[1].valid_for_read) "
        "ok,m=B.take(p,f,5,true) out[#out+1]='copy '..tostring(ok)..' n='..#(hand[1].get_blueprint_entities() or {})..' still='..tostring(f.blueprints[5].valid_for_read) "
        "ok,m=B.take(p,f,5,true) out[#out+1]='full-hand '..tostring(ok)..':'..serpent.line(m) "
        "hand[1].clear() ok,m=B.take(p,f,5,false) out[#out+1]='move '..tostring(ok)..' slot5='..tostring(f.blueprints[5].valid_for_read) "
        "hand[1].set_stack{name='iron-plate',count=5} ok,m=B.store(p,f) out[#out+1]='iron '..tostring(ok)..':'..serpent.line(m) "
        "rcon.print(table.concat(out,' | '))"))
    errors = [l for l in (LAB / 'server.log').read_text(encoding='utf-8', errors='replace').splitlines() if 'Error' in l]
    print('errors:', errors[-5:])
finally:
    proc.kill()
