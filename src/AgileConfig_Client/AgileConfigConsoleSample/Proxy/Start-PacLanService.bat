@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo 用法示例（修改为你的 v2ray 对局域网可见的 HTTP 入站）:
echo   pac-lan-service.ps1 -ProxyHost 192.168.201.51 -ProxyPort 10809
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pac-lan-service.ps1" %*
if errorlevel 1 pause
