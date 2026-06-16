import subprocess
import sys
import os

sys.stdout.reconfigure(encoding='utf-8')

# Get the directory where this script is located
script_dir = os.path.dirname(os.path.abspath(__file__))

args = sys.argv[1:]
result = subprocess.run(['lua'] + args, capture_output=True, text=True, encoding='cp1251', cwd=script_dir)
print(result.stdout, end='')
if result.stderr:
    print(result.stderr, end='', file=sys.stderr)
sys.exit(result.returncode)
