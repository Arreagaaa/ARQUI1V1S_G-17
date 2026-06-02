# Checklist física de Raspberry Pi

Esta lista deja ordenada la parte física que falta para conectar la maqueta real con la Raspberry Pi 3.

## 1. Maqueta física

- [ ] Construir la base del invernadero.
- [ ] Dividir claramente el espacio en área 1, área 2 y centro de control.
- [ ] Colocar plantas reales o simuladas.
- [ ] Colocar recipientes o suelo para cultivo.
- [ ] Instalar la estructura visible del invernadero.

## 2. Sensores y actuadores

- [ ] Conectar sensor ambiental.
- [ ] Conectar sensor de humedad de suelo en área 1.
- [ ] Conectar sensor de humedad de suelo en área 2.
- [ ] Conectar sensor de luz.
- [ ] Conectar sensor de gas.
- [ ] Conectar bomba de agua o equivalente.
- [ ] Conectar ventilación.
- [ ] Conectar iluminación.
- [ ] Conectar buzzer.

## 3. Centro de control

- [ ] Montar la pantalla LCD.
- [ ] Montar botones físicos de control local.
- [ ] Confirmar LEDs de estado.
- [ ] Etiquetar el modo automático y manual.

## 4. GPIO sugerido

- `GPIO_PUMP_AREA_1=17`
- `GPIO_PUMP_AREA_2=27`
- `GPIO_FAN=22`
- `GPIO_LIGHTS=23`
- `GPIO_BUZZER=24`
- `LCD_RS=5`
- `LCD_E=6`
- `LCD_D4=12`
- `LCD_D5=13`
- `LCD_D6=19`
- `LCD_D7=26`
- `BUTTON_MODE=16`
- `BUTTON_MANUAL=20`
- `BUTTON_AUTO=21`

## 5. Red y software

- [ ] Definir broker MQTT.
- [ ] Configurar `MQTT_BASE_TOPIC`.
- [ ] Configurar el backend en la Raspberry.
- [ ] Validar publicación y suscripción MQTT.
- [ ] Probar inserción de lecturas en MongoDB.

## 6. Pruebas mínimas

- [ ] Enviar un comando desde el dashboard.
- [ ] Verificar que la Raspberry lo reciba.
- [ ] Verificar que el actuador cambie.
- [ ] Verificar que el log quede en el backend.
- [ ] Verificar que la lectura aparezca en el dashboard.