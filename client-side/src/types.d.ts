declare global {
  interface Window { __INITIAL_STATE__: RoomState; }
}

export type RoomState = {
  djState: MusicStream,
  userQueue: User[]
}

export type MusicStream = {
  status: MusicStreamStatus,
  songId?: string,
}

export type User = {
  userName: string,
  hexColor: string,
  isAdmin: boolean,
  isConnectedToMusicStream: boolean,
  isConnnectedToRoomEvents: boolean,
};

export type FmtSubChunk = {
  subchunk1Id: string,
  subchunk1Size: number,
  audioFormat: number,
  numChannels: number,
  sampleRate: number,
  byteRate: number,
  blockAlign: number,
  bitsPerSample: number,
  cbSize: number,
  validBitsPerSample: number,
  channelMask: number,
}

export type WsWorkerOpts = {
  type: "INIT",
  roomId: string,
  host: string,
  writeSharedBuffers: WriteSharedBuffers,
  buffers: WsBuffers,
  _audioWorkletOwnedBuffers: AudioWorkletBuffers,
}

// Only the ws worker has access to write to these buffers
export type WsBuffers = {
  writerOffset: SharedArrayBuffer,
  samplesWritten: SharedArrayBuffer,
}

export type WsBuffersView = {
  writerOffset: Int32Array,
  samplesWritten: Int32Array,
}

// Only the audio worklet has access to write from these buffers
export type AudioWorkletBuffers = {
  readerOffset: SharedArrayBuffer,
  samplesRead: SharedArrayBuffer,
}

export type AudioWorkletBuffersView = {
  readerOffset: Int32Array,
  samplesRead: Int32Array,
}

// Both the audio worklet and the ws worker have access to write to these buffers
export type WriteSharedBuffers = {
  ringBuffer: SharedArrayBuffer,
  bufferReady: SharedArrayBuffer,
  sampleIndexBreak: SharedArrayBuffer,
}

export type WriteSharedBuffersView = {
  ringBuffer: Float32Array,
  ringBufferDataView: DataView,
  bufferReady: Uint8Array,
  sampleIndexBreak: Int32Array,
}

export type AudioStreamPrepOptions = {
  ringBufferSize: number,
}

export type WsSongFinishedEvent = {
  type: "WRITE_SONG_FINISHED";
  offset: number;
}

export type WsSongStartedEvent = {
  type: "WRITE_SONG_STARTED";
  title: string;
}

export type WsWorkerEvent = { type: "WS_WORKER_READY" } | WsSongStartedEvent | WsSongFinishedEvent

export type AudioWorkletCommand = {
  type: "WRITE_SONG_STARTED",
} | WsSongFinishedEvent;

export type AudioWorkletEvent = {
  type: "READ_SONG_STARTED" | "READ_SONG_FINISHED",
}

export type RoomMessageType = "ServerWelcomeCommand" | "ServerUploadSongCommand" | "NextInQueueEvent" | "MusicStartedEvent" | "CountingDownEvent" | "SongUploadedEvent" | "SongUploadTimeoutEvent" | "UserEnterEvent" | "UserLeftEvent";

export type CountingDownEvent = {
  s: number,
}

export type MusicStartedEvent = {}
export type NextInQueueEvent = {}

export type SongUploadedEvent = {
  title: string,
}

export type SongUploadTimeoutEvent = {}

export type UserEnterEvent = {
  user: User,
}

export type ServerUploadSongCommand = {}
export type SongFinishedEvent = {}
export type UserAudioPreparedEvent = {
  userId: string
}
export type UserLeftEvent = {
  userId: string
}

export type RoomMessage = (ServerWelcomeCommand | ServerUploadSongCommand | UserEnterEvent | UserLeftEvent | SongUploadedEvent | SongUploadTimeoutEvent | CountingDownEvent | NextInQueueEvent | MusicStartedEvent) & { type: RoomMessageType };

export type AudioChunk = ArrayBuffer;

export type EnqueueSongRequest = {
  priority: number,
}

export type AudioEvent = CountingDownEvent;

export type Song = File | UrlUpload;

export type UrlUpload = {
  url: string,
  valid?: boolean,
  title?: string,
};

export type RoomView = {
  orderView: OrderView;
  currentlyPlayingView: CurrentlyPlayingView;
}

export type OrderView = {
  turn: number;
  users: UserView[];
}

export type UserView = {
  userName: string;
}

export type CurrentlyPlayingView = {
  musicState: MusicStreamerState;
  song: string | null;
  countdown: string | null;
}

export type MusicStreamerState = 'Streaming' | 'Countdown' | 'Polling' | 'NotRunning';
