import { AudioChunk, AudioWorkletBuffersView, FmtSubChunk, WriteSharedBuffersView, WsBuffersView, WsWorkerOpts } from "../modules/interface";

let roomId: string;
let ws: WebSocket;

let buffers: WsBuffersView;
let writeSharedBuffers: WriteSharedBuffersView;
let _audioWorkletBuffers: AudioWorkletBuffersView;

let lappedCount: number = 1;


const parseFmtSubChunk = (data: ArrayBuffer): FmtSubChunk => {
  const view = new DataView(data);
  return {
    // ascii
    subchunk1Id: String.fromCharCode(view.getUint8(0), view.getUint8(1), view.getUint8(2), view.getUint8(3)),
    subchunk1Size: view.getUint32(4, true),
    audioFormat: view.getUint16(8, true),
    numChannels: view.getUint16(10, true),
    sampleRate: view.getUint32(12, true),
    byteRate: view.getUint32(16, true),
    blockAlign: view.getUint16(20, true),
    bitsPerSample: view.getUint16(22, true),
    cbSize: view.getUint16(24, true),
    validBitsPerSample: view.getUint16(26, true),
    channelMask: view.getUint32(28, true),
  }
}
const resetMyState = () => {
  buffers.writerOffset[0] = 0;
  lappedCount = 1;
}

const onWsMessage = (event: MessageEvent<AudioChunk>) => {
  if (event.data.byteLength == 48) {

        const fmtSubChunk = parseFmtSubChunk(event.data);
        // Clear samples written on new song start
        // because the audio worklet still references the old song's samples written to check
        // for buffer underruns
        buffers.samplesWritten[0] = 0;
        postMessage({ type: 'WRITE_SONG_STARTED', byteRate: fmtSubChunk.byteRate });
        return;
  }
  else if (event.data.byteLength == 1) {
      const signal = new DataView(event.data).getInt8(0); 
      if (signal == 0) {  // 0 means the song is over 
        postMessage({ type: 'WRITE_SONG_FINISHED', offset: buffers.writerOffset[0] });
        writeSharedBuffers.sampleIndexBreak[0] = buffers.writerOffset[0];
        resetMyState();
      }       return;
  }

  const data = new Float32Array(event.data);
  if (data.length <= writeSharedBuffers.ringBuffer.length - buffers.writerOffset[0]) {
    // If there's enough space for the data, simply copy it to the ring buffer
    writeSharedBuffers.ringBuffer.set(data, buffers.writerOffset[0]);
  } else {
    // If the data exceeds the space left in the ring buffer, wrap it around
    const remainingSpace = writeSharedBuffers.ringBuffer.length - buffers.writerOffset[0];
    writeSharedBuffers.ringBuffer.set(data.subarray(0, remainingSpace), buffers.writerOffset[0]);
    writeSharedBuffers.ringBuffer.set(data.subarray(remainingSpace), 0);
  }

  buffers.samplesWritten[0] = buffers.samplesWritten[0] + data.length;

  // Lap Detection
  if ((buffers.samplesWritten[0] - _audioWorkletBuffers.samplesRead[0]) > (writeSharedBuffers.ringBuffer.length * lappedCount)) {
    lappedCount += 1;
    console.log(`Buffer overrun!`);
  }

  buffers.writerOffset[0] = (buffers.writerOffset[0] + data.length) % writeSharedBuffers.ringBuffer.length;
  
  // Ring buffer is half full; allow worklet to start reading,
  if (writeSharedBuffers.bufferReady[0] == 0 && (buffers.samplesWritten[0] > (writeSharedBuffers.ringBuffer.length / 8))) {
    writeSharedBuffers.bufferReady[0] = 1;
  }

};

const connectToAudioSocket = (roomId: string, host: string) => {
    ws = new WebSocket(`wss://${host}/${roomId}/music`);
    ws.binaryType = 'arraybuffer';
    ws.addEventListener("message", onWsMessage); 
}

self.onmessage = (messageEvent: MessageEvent<WsWorkerOpts>) => {
  const data = messageEvent.data;
  if (data.type === "INIT") {

    buffers = {
      writerOffset: new Int32Array(data.buffers.writerOffset),
      samplesWritten: new Int32Array(data.buffers.samplesWritten),
    }

    writeSharedBuffers = { 
      ringBuffer: new Float32Array(data.writeSharedBuffers.ringBuffer),
      ringBufferDataView: new DataView(data.writeSharedBuffers.ringBuffer),
      bufferReady: new Uint8Array(data.writeSharedBuffers.bufferReady),
      sampleIndexBreak: new Int32Array(data.writeSharedBuffers.sampleIndexBreak),
    };
    writeSharedBuffers.sampleIndexBreak[0] = -1;

    _audioWorkletBuffers = {
      readerOffset: new Int32Array(data._audioWorkletOwnedBuffers.readerOffset),
      samplesRead: new Int32Array(data._audioWorkletOwnedBuffers.samplesRead),
    }

    connectToAudioSocket(data.roomId, data.host);

    postMessage({ type: 'WS_WORKER_READY' });
  } 

};

