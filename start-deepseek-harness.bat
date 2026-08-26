@echo off
setlocal

rem DeepSeek Harness launcher for Windows
set "DSH_DIR=D:\Project_Game\tools\deepseek-harness"
set "DSH_URL=http://127.0.0.1:3080"

if not exist "%DSH_DIR%\package.json" (
  echo [ERROR] Khong tim thay DeepSeek Harness tai:
  echo         %DSH_DIR%
  pause
  exit /b 1
)

where pnpm >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Khong tim thay pnpm trong PATH.
  echo         Hay cai Node.js va pnpm, sau do chay lai file nay.
  pause
  exit /b 1
)

cd /d "%DSH_DIR%"
echo Dang khoi dong DeepSeek Harness...
echo Truy cap: %DSH_URL%

rem Mo trinh duyet sau khi server co thoi gian khoi dong.
start "" /b powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 3; Start-Process '%DSH_URL%'"

rem Giu cua so nay mo de xem log; nhan Ctrl+C de dung Harness.
pnpm dsh web

endlocal
