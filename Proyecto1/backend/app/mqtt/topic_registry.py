"""
MQTTTopicRegistry — Registro centralizado de todos los topics MQTT oficiales.

Contrato oficial (enunciado ACYE1 — Invernadero Inteligente IoT):
  Broker: broker.emqx.io
  Puertos: 1883 (Python TCP), 8883 (Python SSL), 8084 (MQTTX Web WSS)
  Topic base: grupo17/invernadero  (prefijo de grupo para evitar colisiones en broker público)

NO usar Docker. NO usar Mosquitto local. NO crear brokers propios.
La integración cliente utiliza MQTTX Web (wss://broker.emqx.io:8084).
"""

from ..config import get_settings


class MQTTTopicRegistry:
    """
    Registro centralizado de topics MQTT según el contrato oficial
    del proyecto de invernadero inteligente IoT.

    Todos los topics siguen la estructura:
      grupo17/invernadero/<categoría>/<subcategoría>
    """

    def __init__(self, base_topic: str | None = None):
        self.base = base_topic or get_settings().mqtt_base_topic

    # --- Helpers ---

    def _topic(self, suffix: str) -> str:
        return f"{self.base}/{suffix}"

    # --- Sensores ---

    @property
    def sensor_temperature(self) -> str:
        return self._topic("sensores/temperatura")

    @property
    def sensor_humidity(self) -> str:
        return self._topic("sensores/humedad_ambiente")

    @property
    def sensor_soil_area1(self) -> str:
        return self._topic("sensores/humedad_suelo_area1")

    @property
    def sensor_soil_area2(self) -> str:
        return self._topic("sensores/humedad_suelo_area2")

    @property
    def sensor_light(self) -> str:
        return self._topic("sensores/luz")

    @property
    def sensor_gas(self) -> str:
        return self._topic("sensores/gas")

    @property
    def all_sensor_topics(self) -> list[str]:
        return [
            self.sensor_temperature,
            self.sensor_humidity,
            self.sensor_soil_area1,
            self.sensor_soil_area2,
            self.sensor_light,
            self.sensor_gas,
        ]

    # --- Actuadores ---

    @property
    def actuator_irrigation(self) -> str:
        return self._topic("actuadores/riego")

    @property
    def actuator_irrigation_area1(self) -> str:
        return self._topic("actuadores/riego_area1")

    @property
    def actuator_irrigation_area2(self) -> str:
        return self._topic("actuadores/riego_area2")

    @property
    def actuator_fan(self) -> str:
        return self._topic("actuadores/ventilador")

    @property
    def actuator_lights(self) -> str:
        return self._topic("actuadores/luces")

    @property
    def actuator_alarm(self) -> str:
        return self._topic("actuadores/alarma")

    @property
    def all_actuator_topics(self) -> list[str]:
        return [
            self.actuator_irrigation,
            self.actuator_irrigation_area1,
            self.actuator_irrigation_area2,
            self.actuator_fan,
            self.actuator_lights,
            self.actuator_alarm,
        ]

    # --- Control ---

    @property
    def control_remote(self) -> str:
        return self._topic("control/remoto")

    @property
    def control_manual(self) -> str:
        return self._topic("control/manual")

    @property
    def all_control_topics(self) -> list[str]:
        return [
            self.control_remote,
            self.control_manual,
        ]

    # --- Estado Global ---

    @property
    def global_state(self) -> str:
        return self._topic("estado/global")

    # --- Listado completo ---

    @property
    def all_topics(self) -> list[str]:
        return (
            self.all_sensor_topics
            + self.all_actuator_topics
            + self.all_control_topics
            + [self.global_state]
        )

    def get_sensor_topic(self, sensor_type: str) -> str:
        """Devuelve el topic MQTT para un tipo de sensor dado."""
        mapping = {
            "temperature": self.sensor_temperature,
            "temperatura": self.sensor_temperature,
            "humidity": self.sensor_humidity,
            "humedad": self.sensor_humidity,
            "humedad_ambiente": self.sensor_humidity,
            "soil_1": self.sensor_soil_area1,
            "humedad_suelo_area1": self.sensor_soil_area1,
            "soil_2": self.sensor_soil_area2,
            "humedad_suelo_area2": self.sensor_soil_area2,
            "light": self.sensor_light,
            "luz": self.sensor_light,
            "gas": self.sensor_gas,
        }
        return mapping.get(sensor_type.lower(), self._topic(f"sensores/{sensor_type}"))

    def get_actuator_topic(self, actuator: str, area: str | None = None) -> str:
        """Devuelve el topic MQTT para un actuador dado."""
        if actuator == "pump" and area == "area_1":
            return self.actuator_irrigation_area1
        if actuator == "pump" and area == "area_2":
            return self.actuator_irrigation_area2
        if actuator == "pump":
            return self.actuator_irrigation

        mapping = {
            "fan": self.actuator_fan,
            "lights": self.actuator_lights,
            "buzzer": self.actuator_alarm,
            "alarm": self.actuator_alarm,
        }
        return mapping.get(actuator.lower(), self._topic(f"actuadores/{actuator}"))
