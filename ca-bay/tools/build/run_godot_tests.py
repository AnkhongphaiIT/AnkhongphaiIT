"""Chạy test GDScript headless: import dự án (cập nhật class_name) rồi chạy tests/godot/test_runner.tscn.

    python3 tools/build/run_godot_tests.py [--only=<chuỗi>]
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def godot_bin() -> str:
    return os.environ.get("GODOT_BIN") or shutil.which("godot") or "/opt/godot/4.7.2/godot"


def main() -> int:
    g = godot_bin()
    imp = subprocess.run([g, "--headless", "--path", str(ROOT), "--import"], capture_output=True, text=True, timeout=600)
    if imp.returncode != 0:
        print(imp.stdout[-4000:], imp.stderr[-4000:])
        return imp.returncode
    extra = [a for a in sys.argv[1:]]
    try:
        run = subprocess.run([g, "--headless", "--path", str(ROOT), "res://tests/godot/test_runner.tscn", "--", *extra],
                             capture_output=True, text=True, timeout=900)
    except subprocess.TimeoutExpired:
        print("GODOT_TESTS timeout")
        return 2
    out = run.stdout + run.stderr
    script_errors = 0
    for line in out.splitlines():
        if line.startswith("SCRIPT ERROR"):
            script_errors += 1
        if line.startswith(("FAIL", "GODOT_TESTS", "SCRIPT ERROR", "ERROR", "  at:", "   at:")) or "Parse Error" in line:
            print(line)
    if script_errors:
        print(f"GODOT_TESTS script_errors={script_errors} -> FAIL")
        return 1
    return run.returncode


if __name__ == "__main__":
    sys.exit(main())
