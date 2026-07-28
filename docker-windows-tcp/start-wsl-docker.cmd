@echo off
REM Boot the DEFAULT WSL distro at logon. systemd then starts docker.service (enabled),
REM which opens tcp://127.0.0.1:2375 via the drop-in override. No manual dockerd.
REM The distro name is deliberately NOT hardcoded: it differs per PC
REM (Ubuntu / Ubuntu-24.04 / ...), and a mismatch fails silently here (.vbs hides the console).
REM To pin one, change the line below to:  wsl.exe -d "Ubuntu-24.04" -e true
wsl.exe -e true
