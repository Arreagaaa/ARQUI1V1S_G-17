# Raspberry Pi

Servicio base para la Raspberry Pi 3 del invernadero.

## Qué hace

- se conecta al broker MQTT,
- escucha órdenes de control,
- prepara el mapeo de GPIO,
- reporta estado y logs al backend.

## Antes de usarlo

1. Copiar `.env.example` a `.env`.
2. Ajustar `BACKEND_URL` al backend real.
3. Ajustar `MQTT_HOST`, `MQTT_PORT` y credenciales.
4. Activar `ENABLE_GPIO=true` solo cuando el hardware esté conectado.

## Ejecución

```bash
cd Proyecto1/raspberry
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python main.py
```