@echo off
rem CA BAY - choi thu tren may nay bang mot cong (http://127.0.0.1:8787). Xem README.md muc 0.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run\choi_thu.ps1"
if errorlevel 1 pause
