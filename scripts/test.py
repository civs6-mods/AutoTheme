from pathlib import Path
import subprocess,sys
r=Path(__file__).resolve().parents[1]
runner=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else r/'node_modules/fengari-node-cli/src/lua-cli.js'
assert runner.is_file(),'Run npm ci first, or provide a Fengari CLI path'
for name in ['planner.lua','availability.lua','interactions.lua']:subprocess.run(['node',str(runner),str(r/'tests'/name)],cwd=r,check=True)

subprocess.run([sys.executable,str(r/'tests/test_localization.py')],check=True)
