@echo off
REM Boot WSL(Ubuntu) at logon. systemd then starts docker.service (enabled),
REM which opens tcp://127.0.0.1:2375 via the drop-in override. No manual dockerd.
wsl.exe -d Ubuntu -e true
