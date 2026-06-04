@echo off
REM ============================================
REM Invernadero IoT - Script de inicio
REM Ejecuta con doble click o: start.bat
REM Detecta automaticamente el Python con uvicorn instalado
REM ============================================

REM Candidatos a Python, en orden de prioridad
set "PY_CANDIDATES=python py C:\Users\crjav\AppData\Local\Programs\Python\Python313\python.exe C:\Python313\python.exe C:\Python312\python.exe"

set "PY="
set "PY_FOUND="

echo [1/5] Buscando Python con uvicorn instalado...
for %%P in (%PY_CANDIDATES%) do (
  if not defined PY_FOUND (
    where %%P >nul 2>&1
    if not errorlevel 1 (
      REM Probar si tiene uvicorn
      %%P -c "import uvicorn" >nul 2>&1
      if not errorlevel 1 (
        set "PY=%%P"
        set "PY_FOUND=1"
        echo       OK  %%P  ^(uvicorn OK^)
      ) else (
        echo       ~~  %%P existe pero sin uvicorn
      )
    )
  )
)

if not defined PY_FOUND (
  echo.
  echo ERROR: Ningun Python con uvicorn instalado.
  echo Soluciones:
  echo   1. Activar venv del backend:  cd Proyecto1\backend ^&^& venv\Scripts\activate
  echo   2. Instalar dependencias:     cd Proyecto1\backend ^&^& pip install -r requirements.txt
  pause
  exit /b 1
)

echo       Usando: %PY%
%PY% --version

echo.
echo [2/5] Verificando MongoDB...
tasklist /FI "IMAGENAME eq mongod.exe" 2>NUL | find /I /N "mongod.exe">NUL
if errorlevel 1 (
  echo       ADVERTENCIA: MongoDB no esta corriendo. Inicialo antes de continuar.
  echo       (El backend fallara al conectar a mongodb://localhost:27017)
)

echo.
echo [3/5] Iniciando Backend en ventana nueva...
start "Backend - Invernadero" cmd /k "%~dp0_start_backend.bat" "%PY%"

REM Esperar 3 segundos para que el backend arranque
timeout /t 3 /nobreak >nul

echo [4/5] Iniciando Frontend en ventana nueva...
start "Frontend - Dashboard" cmd /k "%~dp0_start_frontend.bat"

echo.
echo [5/5] Esperando 8s y verificando...
timeout /t 8 /nobreak >nul
%PY% -c "import urllib.request,json; r=urllib.request.urlopen('http://127.0.0.1:8080/api/health',timeout=3); d=json.loads(r.read()); print('      health:', d.get('status'), '| mongodb:', d.get('mongodb'), '| mqtt_connected:', d.get('mqtt_connected'))" 2>nul || echo       ^(backend aun levantando, esperá unos segundos^)

echo.
echo ============================================
echo  Backend:  http://localhost:8080
echo  Swagger:  http://localhost:8080/docs
echo  Frontend: http://localhost:5173
echo  MQTTX:    https://mqttx.app/web
echo ============================================
echo.
echo Las dos ventanas se abrieron. Cierra esta cuando termines.
echo Para detener todo: cierra las dos ventanas.
echo.
pause
