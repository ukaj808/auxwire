<script lang="ts">
import { AuxAudioPlayer, type AuxAudioPlayerEvent, type StreamStartingEvent } from "../modules/aux-audio-player";
import { type CurrentlyPlayingView, type MusicStreamerState, type RoomMessage, type RoomView, type CountingDownEvent, type SongUploadTimeoutEvent, type SongUploadedEvent } from "../modules/interface";
import { RestClient } from "../modules/rest-client";
import { RoomMessageListener } from "../modules/room-message-listener";
import { AudioVisualizer } from "../modules/audio-visualizer";
import { createMachine, fromPromise, interpret } from "xstate";

export class CurrentlyPlayingElement {

  private musicPlayerSectionEl: HTMLElement;
  private canvasMachine: any;
  private listenMachine: any;
  private roomMessageListener: RoomMessageListener;
  private restClient: RestClient;
  private auxAudioPlayer: AuxAudioPlayer;
  private audioVisualizer: AudioVisualizer;
  private analyser: AnalyserNode;
  private listening: boolean;
  private audioCanvas: HTMLCanvasElement;
  private overlayEl: HTMLDivElement;
  private description: HTMLSpanElement;
  private status: HTMLSpanElement;
  private connectBtn: HTMLButtonElement
  private countdownTimer: HTMLSpanElement;
  private loadingBars: HTMLDivElement;
  private initialState: MusicStreamerState;

  constructor(roomMessageListener: RoomMessageListener, restClient: RestClient, auxAudioPlayer: AuxAudioPlayer, analyser: AnalyserNode) {

    const musicPlayerSectionEl = document.getElementById("music-player-section");
    if (!musicPlayerSectionEl) throw new Error('No currently playing element found');
    this.musicPlayerSectionEl = musicPlayerSectionEl;

    const audioCanvas = document.getElementById("audio-visualizer") as HTMLCanvasElement;
    if (!audioCanvas) throw new Error('No audio canvas element found');
    this.audioCanvas = audioCanvas;

    const overlayEl = document.getElementById("cp-overlay");
    if (!overlayEl) throw new Error('No overlay element found');
    this.overlayEl = overlayEl as HTMLDivElement;

    const connectBtn = document.getElementById("cp-connect-btn");
    if (!connectBtn) throw new Error('No disconnect button element found');
    this.connectBtn = connectBtn as HTMLButtonElement;

    const status = document.getElementById("cp-status");
    if (!status) throw new Error('No status element found');
    this.status = status as HTMLSpanElement;

    const countdownTimer = document.getElementById("cp-timer");
    if (!countdownTimer) throw new Error('No countdown timer element found');
    this.countdownTimer = countdownTimer as HTMLSpanElement;

    const loadingBars = document.getElementById("cp-loading");
    if (!loadingBars) throw new Error('No loading bars element found');
    this.loadingBars = loadingBars as HTMLDivElement;

    const description = document.getElementById("cp-desc");
    if (!description) throw new Error('No description element found');
    this.description = description as HTMLSpanElement;

    const state = musicPlayerSectionEl.getAttribute('data-state');
    if (!state) throw new Error('No initial state found');
    this.initialState = state as MusicStreamerState;

    this.roomMessageListener = roomMessageListener;

    this.auxAudioPlayer = auxAudioPlayer;

    this.audioVisualizer = new AudioVisualizer(analyser, audioCanvas);

    this.listening = false;
    this.restClient = restClient;
    this.analyser = analyser;
    this.analyser.fftSize = 256;


    this.canvasMachine = createMachine({
    id: 'canvas',
    initial: this.initialState,
    states: {
      NotRunning: {
        entry: ['showWaitingForCreator'],
        exit: ['hideWaitingForCreator'],
        on: {
          COUNTDOWN_STARTED:{ target: 'Countdown' }, 
        },
      },
      Countdown: {
        entry: ['showCountdown'],
        exit: ['hideCountdown'],
        on: {
          COUNTDOWN_FINISHED: 'Polling',
        },
      },
      Polling: {
        entry: ['showLoading'],
        exit: ['hideLoading'],
        on: {
          SONG_UPLOADED: { target: 'Streaming' },
          UPLOAD_TIMEOUT: { target: 'Countdown' },
        },
      },
      Streaming: {
        entry: ['showSongTitle', 'startVisualizer'],
        exit: ['hideSongTitle', 'stopVisualizer'],
        on: {
          COUNTDOWN_STARTED: 'Countdown', 
        },
      },
    },
  }, 
  {
    actions: {
      showLoading: () => {
        this.loadingBars.classList.remove('hidden');
      },
      hideLoading: () => {
        this.loadingBars.classList.add('hidden');
      }, 
      showCountdown: () => {
        this.countdownTimer.classList.remove('hidden');
      },
      hideCountdown: () => {
        this.countdownTimer.classList.add('hidden');
      },
      showSongTitle: () => {
        this.description.classList.remove('hidden');
      },
      hideSongTitle: () => {
        this.description.classList.add('hidden');
        this.description.innerText = "";
      },
      startVisualizer: () => {
        this.audioVisualizer.start();
      },
      stopVisualizer: () => {
        this.audioVisualizer.stop();
      },
      showWaitingForCreator: () => {
        this.description.classList.remove("hidden");
        this.description.innerText = "";
      },
      hideWaitingForCreator: () => {
        this.description.classList.add("hidden");
        this.description.innerText = "";
      },
    },
  });

  this.listenMachine = createMachine({
    id: 'listen',
    initial: 'Disconnected',
    states: {
      Disconnected: {
        entry: ['disconnect'],
        on: {
          CONNECTION_TOGGLE: 'Connected',
        },
      },
      Connected: {
        entry: ['connect'],
        on: {
          CONNECTION_TOGGLE: 'Disconnected',
        },
      },
    },
  },
  {
    actions: {
      connect: () => {
        this.auxAudioPlayer.startListening();
        this.status.innerText = "Connected";
        this.connectBtn.innerText = "Disconnect";
        this.overlayEl.classList.add('invisible');
      },
      disconnect: () => {
        this.auxAudioPlayer.stopListening();
        this.status.innerText = "Disconnected";
        this.connectBtn.innerText = "Connect";
        this.overlayEl.classList.remove('invisible');
      },  
    },
  });
  
    const canvasActor = interpret(this.canvasMachine);
    const listenActor = interpret(this.listenMachine);

    this.roomMessageListener.subscribe('SongUploadTimeoutEvent', (roomEvent: RoomMessage) => {
      canvasActor.send({ type: 'UPLOAD_TIMEOUT' });
    });

    this.roomMessageListener.subscribe('SongUploadedEvent', (roomEvent: RoomMessage) => {
      const songUploadedEvent = roomEvent as SongUploadedEvent;
      this.description.innerText = songUploadedEvent.title;
      canvasActor.send({ type: 'SONG_UPLOADED' });
    });

    this.roomMessageListener.subscribe('CountingDownEvent', (roomEvent: RoomMessage) => {
      const countingDownEvent = roomEvent as CountingDownEvent;  
      this.countdownTimer.innerText = countingDownEvent.s.toString();
      if (countingDownEvent.s === 5) {
        canvasActor.send({ type: 'COUNTDOWN_STARTED' });
      } else if (countingDownEvent.s === 0) {
        canvasActor.send({ type: 'COUNTDOWN_FINISHED' });
      }
    });

    this.connectBtn.addEventListener('click', () => {
      listenActor.send({ type: 'CONNECTION_TOGGLE' });
    });

    listenActor.start();
    canvasActor.start();
  }

}
</script>

<template>
</template>

<style scoped>
</style>
