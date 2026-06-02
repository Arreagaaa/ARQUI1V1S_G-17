# Instructivo físico, Pi 3 y MQTT

Este instructivo deja en orden la siguiente fase del proyecto: maqueta física, Raspberry Pi 3, MQTT y validación del flujo completo.

## Objetivo de esta fase

Dejar la solución lista para que, cuando conectes la Raspberry Pi 3 y la maqueta física, el sistema pueda:

1. Recibir órdenes desde la web.
2. Publicar y consumir mensajes MQTT.
3. Encender y apagar actuadores reales.
4. Registrar lecturas, eventos y estados en el backend.
5. Mostrar información básica en el centro de control físico.

## Flujo general recomendado

### 1. Maqueta física

- Construye la base del invernadero.
- Divide la maqueta en área 1, área 2 y centro de control.
- Coloca plantas reales o simuladas.
- Coloca recipientes o suelo para cultivo.
- Deja visibles mangueras, tuberías, LEDs y estructura.

### 2. Raspberry Pi 3

- Instala Raspberry Pi OS con el imager.
- Habilita SSH si vas a administrarla remótamente.
- Actualiza el sistema.
- Instala Python 3 y dependencias.
- Copia `raspberry/.env.example` a `raspberry/.env`.
- Ajusta `BACKEND_URL`, `MQTT_HOST`, `MQTT_PORT` y `MQTT_BASE_TOPIC`.

### 3. MQTT

- Define un broker local o de red.
- Usa `MQTT_BASE_TOPIC=invernadero` como base inicial.
- Confirma los tópicos:
  - `invernadero/control/#`
  - `invernadero/commands`
- Prueba publicación desde el backend antes de conectar hardware real.

### 4. Centro de control

- Conecta la pantalla LCD.
- Conecta los botones físicos.
- Configura los LEDs de estado.
- Verifica que los pines coincidan con `raspberry/.env`.

### 5. Sensores y actuadores

- Conecta el sensor ambiental.
- Conecta los sensores de humedad de suelo de ambas áreas.
- Conecta el sensor de luz y el sensor de gas.
- Conecta bomba, ventilación, luces y buzzer.
- Haz las pruebas de uno en uno, no todo al mismo tiempo.

### 6. Validación final

- Envía una orden desde la web.
- Verifica que llegue a MQTT.
- Verifica que la Raspberry la reciba.
- Verifica que el actuador responda.
- Verifica que el backend registre el evento y el log.
- Verifica que Compass muestre los datos en MongoDB local.

## Orden de trabajo sugerido

1. Montar la maqueta.
2. Configurar la Raspberry Pi 3.
3. Levantar el backend y MongoDB local.
4. Probar MQTT sin hardware real.
5. Conectar sensores y actuadores.
6. Conectar LCD y botones.
7. Hacer demo final.

## Criterio de avance

No pases al siguiente paso si el anterior no quedó estable. Primero red y backend, después MQTT, luego hardware, y al final la demo.

## Referencias rápidas

- [Guía de Raspberry Pi](raspberry-pi.md)
- [Checklist física de Raspberry Pi](checklist-pi.md)
- [Guía de variables de entorno](env-config.md)
- [Pendientes de integración](pendientes.md)