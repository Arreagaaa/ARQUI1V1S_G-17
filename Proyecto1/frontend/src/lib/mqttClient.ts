import mqtt from 'mqtt';

const MQTT_URL = import.meta.env.VITE_MQTT_URL ?? 'wss://broker.hivemq.com:8884/mqtt';
const CLIENT_ID = import.meta.env.VITE_MQTT_CLIENT_ID ?? 'invernadero_dashboard_17';
const BASE_TOPIC = import.meta.env.VITE_MQTT_BASE_TOPIC ?? 'grupo17/invernadero';

type MessageCallback = (topic: string, payload: Record<string, unknown>) => void;

class MQTTClient {
  private client: mqtt.MqttClient | null = null;
  private callbacks: Map<string, MessageCallback[]> = new Map();
  private onConnectCallbacks: Array<() => void> = [];
  private onDisconnectCallbacks: Array<() => void> = [];

  get connected(): boolean {
    return this.client?.connected ?? false;
  }

  connect(): void {
    if (this.client?.connected) return;

    this.client = mqtt.connect(MQTT_URL, {
      clientId: `${CLIENT_ID}_${Date.now()}`,
      clean: true,
      keepalive: 60,
      reconnectPeriod: 5000,
    });

    this.client.on('connect', () => {
      this.onConnectCallbacks.forEach((cb) => cb());
      this.callbacks.forEach((_, topic) => {
        this.client?.subscribe(topic, { qos: 1 });
      });
    });

    this.client.on('disconnect', () => {
      this.onDisconnectCallbacks.forEach((cb) => cb());
    });

    this.client.on('message', (topic, payload) => {
      try {
        const data = JSON.parse(payload.toString());
        this.callbacks.forEach((cbs, registeredTopic) => {
          if (topic.includes(registeredTopic.replace('#', ''))) {
            cbs.forEach((cb) => cb(topic, data));
          }
        });
      } catch {
        // ignore malformed messages
      }
    });
  }

  disconnect(): void {
    this.client?.end(true);
    this.client = null;
  }

  subscribe(topic: string, callback: MessageCallback): void {
    const fullTopic = `${BASE_TOPIC}/${topic}`;
    if (!this.callbacks.has(fullTopic)) {
      this.callbacks.set(fullTopic, []);
      this.client?.subscribe(fullTopic, { qos: 1 });
    }
    this.callbacks.get(fullTopic)!.push(callback);
  }

  publish(topic: string, payload: Record<string, unknown>): void {
    const fullTopic = `${BASE_TOPIC}/${topic}`;
    if (this.client?.connected) {
      this.client.publish(fullTopic, JSON.stringify(payload), { qos: 1 });
    }
  }

  onConnect(cb: () => void): void {
    this.onConnectCallbacks.push(cb);
  }

  onDisconnect(cb: () => void): void {
    this.onDisconnectCallbacks.push(cb);
  }
}

export const mqttClient = new MQTTClient();
export { BASE_TOPIC };
