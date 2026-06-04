@echo off
REM ============================================
REM Invernadero IoT - Script de inicio
REM Ejecuta con doble click o: start.bat
REM ============================================

set PY=python
where python >nul 2>&1
if errorlevel 1 set PY=py

echo [1/3] Verificando Python...
%PY% --version
if errorlevel 1 (
  echo ERROR: Python no encontrado. Instala Python 3.10+ y agrega al PATH.
  pause
  exit /b 1
)

echo [2/3] Verificando MongoDB...
tasklist /FI "IMAGENAME eq mongod.exe" 2>NUL | find /I /N "mongod.exe">NUL
if errorlevel 1 (
  echo ADVERTENCIA: MongoDB no esta corriendo. Inicialo antes de continuar.
  pause
)

echo [3/3] Iniciando Backend y Frontend...
echo.

REM Lanzar backend en ventana nueva
start "Backend - Invernadero" cmd /k "cd /d %~dp0Proyecto1\backend && %PY% -m uvicorn app.main:app --reload --port 8080"

REM Esperar 3 segundos
timeout /t 3 /nobreak >nul

REM Lanzar frontend en ventana nueva
start "Frontend - Dashboard" cmd /k "cd /d %~dp0Proyecto1\frontend && echo VITE_API_BASE_URL=http://localhost:8080> .env.local && call npm run dev"

echo.
echo ============================================
echo  Backend:  http://localhost:8080
echo  Swagger:  http://localhost:8080/docs
echo  Frontend: http://localhost:5173
echo ============================================
echo.
echo Las dos ventanas se abrieron. Cierra esta cuando termines.
echo Para detener todo: cierra las dos ventanas.
echo.
pause
