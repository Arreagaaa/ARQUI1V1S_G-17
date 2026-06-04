@echo off
REM Script helper para start.bat: arranca el backend.
REM Se invoca como su propio proceso para evitar problemas de quoting
REM con "start ... cmd /k ..." dentro de start.bat.

set "PY=%~1"
cd /d "%~dp0Proyecto1\backend"

echo Backend: usando %PY%
echo Backend: puerto 8080
echo.
echo IMPORTANTE: NO usar --reload (rompe la suscripcion MQTT singleton)
echo.

%PY% -m uvicorn app.main:app --host 127.0.0.1 --port 8080
