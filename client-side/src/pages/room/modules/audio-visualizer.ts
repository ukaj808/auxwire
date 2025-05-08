export class AudioVisualizer {
  private analyser: AnalyserNode;
  private canvas: HTMLCanvasElement;
  private canvasCtx: CanvasRenderingContext2D;
  private buffer: Float32Array;
  private drawVisual?: number;
  
  constructor(analyser: AnalyserNode, canvas: HTMLCanvasElement) {
    this.analyser = analyser;
    this.canvas = canvas;
    this.analyser.fftSize = 256;
    this.buffer = new Float32Array(this.analyser.frequencyBinCount);
    this.canvasCtx = this.canvas.getContext('2d')!;
    this.canvasCtx.clearRect(0, 0, this.canvas.width, this.canvas.height);
  }
  
  public start() {
    this.drawVisual = requestAnimationFrame(this.draw.bind(this));
  }
  
  public stop() {
    if (this.drawVisual) {
      cancelAnimationFrame(this.drawVisual);
      this.canvasCtx.clearRect(0, 0, this.canvas.width, this.canvas.height);
    }
  }
  
  private draw() {
    this.drawVisual = requestAnimationFrame(this.draw.bind(this));
    this.analyser.getFloatFrequencyData(this.buffer);
    this.canvasCtx.fillStyle = 'rgb(48, 49, 53)';
    this.canvasCtx.fillRect(0, 0, this.canvasCtx.canvas.width, this.canvasCtx.canvas.height);
  
    const barWidth = (this.canvasCtx.canvas.width / this.analyser.frequencyBinCount) * 2.5;
    let barHeight;
    let x = 0;
  
    for (let i = 0; i < this.analyser.frequencyBinCount; i++) {
      barHeight = this.buffer[i];
      
      // Create a rainbow color spectrum
      const hue = (i / this.analyser.frequencyBinCount) * 360;
      const color = `hsl(${hue}, 100%, 50%)`;
  
      this.canvasCtx.fillStyle = color;
      this.canvasCtx.fillRect(x, this.canvasCtx.canvas.height - barHeight / 2, barWidth, barHeight);
  
      x += barWidth + 1;
    }
  }
}
