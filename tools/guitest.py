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
    print(r.lua('local p=game.get_player(1) Twelve.demo(p) local id for k in pairs(storage.twelve.ships) do id=k end '
                'local f=Twelve.get(id) Twelve.enter(1,id) rcon.print(id)'))
    time.sleep(2)
    out = LAB / 'shots'; results = {}
    for tab in range(1, 8):
        res = r.lua(f'local ok,err=pcall(function() local p=game.get_player(1) local id for k in pairs(storage.twelve.ships) do id=k end '
                    f'TwelveUI.open(p,id,{tab}) end) rcon.print(ok and "ok" or tostring(err))')
        time.sleep(1.5)
        r.lua(f'game.take_screenshot{{player=1,by_player=1,path="tab{tab}-{LOCALE}.png",show_gui=true,resolution={{1600,1000}}}}')
        results[tab] = res
        print('tab', tab, res)
    time.sleep(3)
    print('server alive:', server.poll() is None)
    print('errors in server log:', [l for l in (LAB / 'server.log').read_text(encoding='utf-8', errors='replace').splitlines() if 'Error' in l][-10:])
finally:
    server.kill()
    lab = str(LAB)
    subprocess.run(['powershell', '-NoProfile', '-Command',
                    "Get-CimInstance Win32_Process -Filter \"Name like 'factorio%'\" | "
                    f"Where-Object {{ $_.CommandLine -like '*{lab}*' }} | ForEach-Object {{ Stop-Process -Id $_.ProcessId -Force }}"])
