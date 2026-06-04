@echo off
REM Script helper para start.bat: arranca el frontend.
REM Se invoca como su propio proceso para evitar problemas de quoting
REM con "start ... cmd /k ..." dentro de start.bat.

cd /d "%~dp0Proyecto1\frontend"

if not exist .env.local (
  echo VITE_API_BASE_URL=http://localhost:8080> .env.local
)

echo Frontend: usando %CD%
echo Frontend: VITE_API_BASE_URL=http://localhost:8080
echo.
echo Corriendo npm run dev...
echo.

REM Llamar a npm.cmd (no npm) por la ExecutionPolicy de PowerShell
call npm.cmd run dev
