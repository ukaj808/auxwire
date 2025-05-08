import { AudioWorkletBuffersView, WriteSharedBuffersView, WsBuffersView } from "../modules/interface";

class AuxWorkletProcessor extends AudioWorkletProcessor {

  private buffersView: AudioWorkletBuffersView;
  private writeSharedBuffersView: WriteSharedBuffersView;
  private _wsBuffersView: WsBuffersView;
  private readStartedEventPublished: boolean = false;

  constructor(options: AudioWorkletNodeOptions) {
    super();
    this.buffersView = {
      readerOffset: new Int32Array(options.processorOptions.buffers.readerOffset),
      samplesRead: new Int32Array(options.processorOptions.buffers.samplesRead),
    } 

    this.writeSharedBuffersView = {
      ringBuffer: new Float32Array(options.processorOptions.writeSharedBuffers.ringBuffer),
      ringBufferDataView: new DataView(options.processorOptions.writeSharedBuffers.ringBuffer),
      bufferReady: new Uint8Array(options.processorOptions.writeSharedBuffers.bufferReady),
      sampleIndexBreak: new Int32Array(options.processorOptions.writeSharedBuffers.sampleIndexBreak),
    }

    this._wsBuffersView = {
      writerOffset: new Int32Array(options.processorOptions._wsBuffers.writerOffset),
      samplesWritten: new Int32Array(options.processorOptions._wsBuffers.samplesWritten),
    }

  }

  private resetMyBuffers() {
    this.buffersView.readerOffset[0] = 0;
    this.buffersView.samplesRead[0] = 0;
  }

  private resetWriteSharedBuffers() {
    this.writeSharedBuffersView.ringBuffer.fill(0);
    this.writeSharedBuffersView.bufferReady[0] = 0;
    this.writeSharedBuffersView.sampleIndexBreak[0] = -1;
  }

  process(_inputs: Float32Array[][], outputs: Float32Array[][]) {
    if (!this.isAudioAvailable()) {
      return true;
    }
    
    if (!this.readStartedEventPublished) {
      this.port.postMessage({ type: 'READ_SONG_STARTED' });
      this.readStartedEventPublished = true;
    }
    
    const output    = outputs[0]; // 1st output source
    const numChannels = output.length;

    let totalSamplesProcessed = 0;

    for (let channel = 0; channel < numChannels; channel++) {
      const outputChannel = output[channel];
      const numSamples = outputChannel.length;
      totalSamplesProcessed += numSamples;
      for (let sample = 0, pcmSample = channel; sample < numSamples; sample++, pcmSample += numChannels) {
        const calcPcmSampleIndex = (this.buffersView.readerOffset[0] + pcmSample) % this.writeSharedBuffersView.ringBuffer.length;
        const dataViewIndex = calcPcmSampleIndex * Float32Array.BYTES_PER_ELEMENT;
        const sampleValue = this.writeSharedBuffersView.ringBufferDataView.getFloat32(dataViewIndex, true);
        outputChannel[sample] = sampleValue;

        // Graceful exit if the song is over
        // -1 signifies a undefined state
        if (this.writeSharedBuffersView.sampleIndexBreak[0] != -1) {
          // consume all samples until the break offset
          if (calcPcmSampleIndex == this.writeSharedBuffersView.sampleIndexBreak[0]) {
            this.resetMyBuffers();
            this.resetWriteSharedBuffers();
            this.readStartedEventPublished = false;
            this.port.postMessage({ type: 'READ_SONG_FINISHED' });
            return true;
          }
        }

      }
    }
    
    this.buffersView.readerOffset[0] = (this.buffersView.readerOffset[0] + totalSamplesProcessed) % this.writeSharedBuffersView.ringBuffer.length;
    this.buffersView.samplesRead[0] = this.buffersView.samplesRead[0] + totalSamplesProcessed;

    if (this.buffersView.samplesRead[0] > this._wsBuffersView.samplesWritten[0]) {
      console.log("samples read: " + this.buffersView.samplesRead[0] + " samples written: " + this._wsBuffersView.samplesWritten[0]);
      console.log("Buffer underrun!");
    }

    return true;

  }

  private isAudioAvailable(){
    return this.writeSharedBuffersView.bufferReady[0] == 1;
  }
}

registerProcessor("audio-worklet-processor", AuxWorkletProcessor);
