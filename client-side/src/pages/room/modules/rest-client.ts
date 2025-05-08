import { type RoomView, type ServerWelcomeCommand, type Song } from "./interface";
import { RoomMessageListener } from "./room-message-listener";

export class RestClient {
  private roomId: string;
  private roomMessageListener: RoomMessageListener;
  private basePath: string;
  private userId?: string;

  constructor(roomId: string, roomMessageListener: RoomMessageListener) {
    this.roomId = roomId;
    this.basePath = `/${roomId}`;
    this.roomMessageListener = roomMessageListener;
    this.roomMessageListener.subscribe("ServerWelcomeCommand", (data) => {
            const welcomeCommand = data as ServerWelcomeCommand;
      this.setUserId(welcomeCommand.userId);
    });
  }

  public setUserId(userId: string) {
    this.userId = userId;
  }

  public getRoom(): Promise<RoomView> {
    return fetch(this.basePath, {
      method: "GET",
      headers: {
        Accept: "application/json",
      },
    }).then((res) => res.json());
  }

  public startMusic(): Promise<Response> {
    if (!this.userId) throw new Error("No user id set");
    return fetch(this.basePath + "/start", {
      method: "PUT",
      headers: {
        "X-User-Id": this.userId,
      },
    });
  }

  public validateUrl(url: string): Promise<string> {
    return fetch("/validate-url", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ url }),
    }).then((res) => res.text());
  }

  public uploadSong(song: Song): Promise<Response> {
        if (!this.userId) throw new Error("No user id set");
    const formData = new FormData();
    if (song instanceof File) {
      formData.append("file", song);
    } else {
      formData.append("url", song.url);
    }
    return fetch(this.basePath + `/upload`, {
      method: "PUT",
      body: formData,
      headers: {
        "X-User-Id": this.userId,
      },
    });
  }
}
