import { EventBus } from "./event-bus";
import { type RoomMessage, type RoomMessageType } from "./interface";

export class RoomMessageListener {

  private roomId: string;
  private ws: WebSocket | null = null;
  private eventBus: EventBus<RoomMessageType, RoomMessage> = new EventBus();
  private host: string;

  constructor(roomId: string) {
    this.roomId = roomId;
    if (window.location.host.includes('localhost')) {
      this.host = 'localhost:8080';
    } else {
      this.host = window.location.host;
    }
  }

  public start() {
    this.ws = new WebSocket(`wss://${window.location.host}/${this.roomId}/ws`);
    this.ws.onmessage = this.process;
  }

  public subscribe(msgType: RoomMessageType, callback: (event: RoomMessage) => void) {
    this.eventBus.subscribe(msgType, callback);
  }

  public unsubscribe(eventType: RoomMessageType, callback: (event: RoomMessage) => void) {
    this.eventBus.unsubscribe(eventType, callback);
  }

  private process = (event: MessageEvent<string>) => {
    console.log(event);
    const data = JSON.parse(event.data) as RoomMessage;
        this.eventBus.publish(data.type, data);
  }
}
