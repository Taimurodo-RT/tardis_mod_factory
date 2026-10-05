"""Build the mod zip and optionally install it into the local Factorio mods folder.

    python package.py            -> ../dist/tardis_<version>.zip
    python package.py --install  -> also copy it to %APPDATA%/Factorio/mods,
                                    moving older tardis_*.zip there to the Recycle Bin
"""
import json, os, pathlib, subprocess, sys, zipfile

sys.stdout.reconfigure(encoding='utf-8')
ROOT = pathlib.Path(__file__).resolve().parent
EXCLUDE = {'.git', '.gitignore', '.gitattributes', 'stylua.toml', 'package.py'}


def build():
    info = json.loads((ROOT / 'info.json').read_text(encoding='utf-8'))
    folder = f"{info['name']}_{info['version']}"
    out = ROOT.parent / 'dist' / f'{folder}.zip'
    out.parent.mkdir(exist_ok=True)
    files = subprocess.run(['git', 'ls-files', '-co', '--exclude-standard'], cwd=ROOT, check=True,
                           capture_output=True, text=True, encoding='utf-8').stdout.splitlines()
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
        for rel in sorted(files):
            if rel.split('/')[0] in EXCLUDE or not (ROOT / rel).is_file():
                continue
            z.write(ROOT / rel, f'{folder}/{rel}')
    print(f'built {out} ({len(z.namelist())} files)')
    return out, info['name']


def install(zip_path, name):
    mods = pathlib.Path(os.environ['APPDATA']) / 'Factorio' / 'mods'
    target = mods / zip_path.name
    target.write_bytes(zip_path.read_bytes())
    print(f'installed {target}')
    old = [p for p in mods.glob(f'{name}_*.zip') if p != target]
    for p in old:
        ps = ("Add-Type -AssemblyName Microsoft.VisualBasic;"
              f"[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile('{p}','OnlyErrorDialogs','SendToRecycleBin')")
        subprocess.run(['powershell', '-NoProfile', '-Command', ps], check=True)
        print(f'recycled {p.name}')


if __name__ == '__main__':
    zip_path, name = build()
    if '--install' in sys.argv:
        install(zip_path, name)
