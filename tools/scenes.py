"""Isolated GUI test: headless server + graphical client, driven over RCON.
Opens every console system for a demo ship and screenshots it, in the given locale."""
import json, pathlib, shutil, socket, struct, subprocess, sys, time
sys.stdout.reconfigure(encoding='utf-8')
SRC = pathlib.Path(sys.argv[1]); LAB = pathlib.Path(sys.argv[2]); LOCALE = sys.argv[3]
GAME = pathlib.Path(r'C:/Program Files (x86)/Steam/steamapps/common/Factorio'); EXE = GAME / 'bin/x64/factorio.exe'
PORT, RCON, PW = 34297, 27099, 'tardis-gui-test'


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
    def lua(self, code):
        i = self.send(2, '/silent-command __tardis__ ' + code)
        while True:
            j, k, v = self.recv()
            if j == i: return v.strip()


if LAB.exists(): shutil.rmtree(LAB)
for d in ['mods', 'server', 'client']: (LAB / d).mkdir(parents=True)
shutil.copytree(SRC, LAB / 'mods/tardis', ignore=shutil.ignore_patterns('.git*', '*.py', 'stylua.toml'))
(LAB / 'mods/mod-list.json').write_text(json.dumps({'mods': [{'name': n, 'enabled': True} for n in
                                                            ['base', 'elevated-rails', 'quality', 'space-age', 'tardis']]}))
for kind in ['server', 'client']:
    (LAB / kind / 'config.ini').write_text(
        f'[path]\nread-data={GAME / "data"}\nwrite-data={LAB / kind}\n[general]\nlocale={LOCALE}\n'
        '[other]\ncheck-updates=false\nshow-tips-and-tricks=false\n[graphics]\nfull-screen=false\nwindow-size=1600x1000\n',
        encoding='utf-8')
(LAB / 'client/player-data.json').write_text(json.dumps({'service-username': 'tester'}))
settings = json.loads((GAME / 'data/server-settings.example.json').read_text())
settings.update({'name': 'tardis gui test', 'visibility': {'public': False, 'lan': False},
                 'require_user_verification': False, 'auto_pause': False, 'autosave_interval': 0})
(LAB / 'server-settings.json').write_text(json.dumps(settings))
(LAB / 'server-adminlist.json').write_text(json.dumps(['tester']))
base = lambda kind: [str(EXE), '--config', str(LAB / kind / 'config.ini'), '--mod-directory', str(LAB / 'mods')]
save = LAB / 'gui.zip'
subprocess.run(base('server') + ['--create', str(save)], check=True, capture_output=True)
server = subprocess.Popen(base('server') + ['--start-server', str(save), '--port', str(PORT), '--rcon-port', str(RCON),
                                            '--rcon-password', PW, '--server-settings', str(LAB / 'server-settings.json'),
                                            '--server-adminlist', str(LAB / 'server-adminlist.json')],
                          stdout=open(LAB / 'server.log', 'w', encoding='utf-8'), stderr=subprocess.STDOUT)
client = None
try:
    deadline = time.time() + 120
    while True:
        try: r = Rcon(); break
        except OSError:
            if time.time() > deadline: raise
            time.sleep(1)
    client = subprocess.Popen(base('client') + ['--mp-connect', f'127.0.0.1:{PORT}', '--disable-audio'],
                              stdout=open(LAB / 'client.log', 'w', encoding='utf-8'), stderr=subprocess.STDOUT)
    deadline = time.time() + 180
    while r.lua('local p=game.get_player(1) rcon.print(p and p.connected and p.character and "y" or "n")') != 'y':
        if time.time() > deadline: raise TimeoutError('client did not join')
        time.sleep(1)
    print('joined')
    LUA_SETUP = (
        "local p=game.get_player(1) Twelve.demo(p) local id for k in pairs(storage.twelve.ships) do id=k end "
        "storage.cap_id=id local f=Twelve.get(id) "
        "for _,it in ipairs{{'iron-plate',5000},{'steel-plate',3000},{'copper-plate',3000},{'electronic-circuit',2000},{'wood',2000}} do f.cargo.insert{name=it[1],count=it[2]} end "
        "local R=Twelve.Rooms local a=R.request(p,f,1,'workshop',Twelve.move) local b=R.request(p,f,2,'vault',Twelve.move) "
        "for _,room in pairs(f.rooms) do room.finish=game.tick+5 end "
        "game.tick_paused=false rcon.print(id..' '..tostring(a)..' '..tostring(b))")
    print(r.lua(LUA_SETUP)); time.sleep(3)
    print(r.lua("local f=Twelve.get(storage.cap_id) local p=game.get_player(1) local R=Twelve.Rooms "
                "local a,m=R.request(p,f,3,'library',Twelve.move) for _,room in pairs(f.rooms) do if room.state=='building' then room.finish=game.tick+5 end end rcon.print(tostring(a))"))
    time.sleep(3)
    print(r.lua("local f=Twelve.get(storage.cap_id) local t={} for k,v in pairs(f.rooms) do local xy=Twelve.Rooms.position(k,f) t[#t+1]=k..':'..v.kind..':'..v.state..'@'..xy.x..','..xy.y end rcon.print(table.concat(t,' '))"))
    shots = [
        ("exterior", "f.box.surface", "f.box.position", 1.0),
        ("console-room", "f.surface", "{0,0}", 0.6),
        ("console-close", "f.surface", "{0,0}", 1.2),
        ("eye-deck", "f.eye_surface", "{0,0}", 0.45),
        ("eye-close", "f.eye_surface", "{0,0}", 1.0),
        ("room-1", "f.surface", "Twelve.Rooms.position(1,f)", 0.7),
        ("room-2", "f.surface", "Twelve.Rooms.position(2,f)", 0.7),
        ("room-3", "f.surface", "Twelve.Rooms.position(3,f)", 0.7),
        ("interior-wide", "f.surface", "{0,-30}", 0.25),
    ]
    r.lua("local f=Twelve.get(storage.cap_id) for _,s in pairs{f.surface,f.eye_surface} do s.request_to_generate_chunks({0,0},6) s.force_generate_chunk_requests() game.forces.player.chart(s,{{-200,-200},{200,200}}) end")
    time.sleep(3)
    ONLY = [x for x in sys.argv[4:]]
    for name, surf, pos, zoom in shots:
        if ONLY and name not in ONLY: continue
        print(name, r.lua(f"local f=Twelve.get(storage.cap_id) local ok,e=pcall(function() game.take_screenshot{{by_player=1,surface={surf},position={pos},zoom={zoom},resolution={{1600,1000}},show_gui=false,show_entity_info=false,daytime=0.5,path='scene-{name}.png'}} end) rcon.print(ok and 'ok' or tostring(e))"))
        time.sleep(1)
    time.sleep(4)
    print('server alive:', server.poll() is None)
    print('errors in server log:', [l for l in (LAB / 'server.log').read_text(encoding='utf-8', errors='replace').splitlines() if 'Error' in l][-10:])
finally:
    server.kill()
    lab = str(LAB)
    subprocess.run(['powershell', '-NoProfile', '-Command',
                    "Get-CimInstance Win32_Process -Filter \"Name like 'factorio%'\" | "
                    f"Where-Object {{ $_.CommandLine -like '*{lab}*' }} | ForEach-Object {{ Stop-Process -Id $_.ProcessId -Force }}"])
