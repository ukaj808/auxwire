let roomId: string;
let userId: string;
let ws: WebSocket;
let ringBuffer: Float32Array;
let state: Int8Array;
let audioWorkletOffset: Int32Array;
let openState: boolean = false;
let offset: number = 0;
let bufferOverunCount: number = 0;

const onWsMessage = (event: MessageEvent<AudioChunk>) => {
  if (event.data.byteLength == 1) {
      const signal = new DataView(event.data).getInt8(0); 
      if (signal == 0) {  // 0 means the song is over 
        console.log("Song is over"); 
        // Clear the ring buffer
        ringBuffer.fill(0);
      } else if (signal == 1) { // 1 means the song is starting 
        console.log("Song is starting");
      }
      return;
  }

  const data = new Float32Array(event.data);
  if (data.length <= ringBuffer.length - offset) {
    // If there's enough space for the data, simply copy it to the ring buffer
    ringBuffer.set(data, offset);
  } else {
    // If the data exceeds the space left in the ring buffer, wrap it around
    const remainingSpace = ringBuffer.length - offset;
    ringBuffer.set(data.subarray(0, remainingSpace), offset);
    ringBuffer.set(data.subarray(remainingSpace), 0);
  }

  offset = (offset + data.length) % ringBuffer.length;  
  
  // Ring buffer is half full; allow worklet to start reading,
  if (!openState && offset >= ringBuffer.length / 2) {
    openState = true;
    Atomics.store(state, 0, 1);
  }

  const workletOffset = Atomics.load(audioWorkletOffset, 0);
  // The worklet offset should start out behind the worker offset since
  // we give this worker a head start on filling the ring buffer
  // If the worklet offset passes the worker offset, thats a buffer overrun
  // and we should log it
  if (workletOffset > offset) {
    bufferOverunCount++;
    console.log(`Buffer overrun count: ${bufferOverunCount}`, `Worklet offset: ${workletOffset}`, `Worker offset: ${offset}`);
  } else {
    console.log(`Worklet offset: ${workletOffset}`, `Worker offset: ${offset}`);
  }

};

const connectToAudioSocket = (roomId: string, userId: string) => {
    ws = new WebSocket(`ws://localhost:8080/${roomId}/users/${userId}/music/listen`);
    ws.binaryType = 'arraybuffer';
    ws.addEventListener("message", onWsMessage); 
}

self.onmessage = (messageEvent: MessageEvent<WsWorkerOpts>) => {
  const data = messageEvent.data;
  if (data.type === "INIT") {
    // Create views on shared buffers
    ringBuffer     = new Float32Array(data.ringBuffer);
    state          = new Int8Array(data.state);
    audioWorkletOffset = new Int32Array(data.audioWorkletOffset);

    connectToAudioSocket(data.roomId, data.userId)

    postMessage({ type: 'WS_WORKER_READY' });
  } 

};

