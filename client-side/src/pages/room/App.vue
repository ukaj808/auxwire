/*
import { AuxAudioPlayer } from "./modules/aux-audio-player";
import { RoomMessageListener } from "./modules/room-message-listener";
// import { UserQueueElement } from "./modules/user-section-element";
// import { DropElement } from "./modules/drop-element";
// import { CurrentlyPlayingElement } from "./modules/currently-playing/currently-playing-element";
import { RestClient } from "./modules/rest-client";
import { SvgFactory } from "./modules/svg";
// @ts-ignore
import { SongQueue } from "./modules/song-queue";
import { LoaderFactory } from "./modules/loader";
import { MutableStyleSheet } from "./modules/stylesheet-manipulations";

let roomId: string = location.pathname.substr(1);
let listening: boolean = false;
const mobileStyleSheet = new MutableStyleSheet((document.getElementById('room-mobile-stylesheet') as
HTMLLinkElement).sheet!);
const desktopStyleSheet = new MutableStyleSheet((document.getElementById('room-desktop-stylesheet') as
HTMLLinkElement).sheet!);

const roomMessageListener: RoomMessageListener = new RoomMessageListener(roomId);
const audioContext = new AudioContext({
latencyHint: "playback",
sampleRate: 48000,
});
const analyser = audioContext.createAnalyser();
const svgFactory: SvgFactory = new SvgFactory();
const loaderFactory: LoaderFactory = new LoaderFactory();
const auxAudioPlayer: AuxAudioPlayer = new AuxAudioPlayer(roomId, audioContext, analyser, roomMessageListener);
const restClient: RestClient = new RestClient(roomId, roomMessageListener);
// const currentlyPlayingElement: CurrentlyPlayingElement
// = new CurrentlyPlayingElement(roomMessageListener, restClient, auxAudioPlayer, analyser);
// const dropElement: DropElement = new DropElement(roomMessageListener, restClient, loaderFactory, svgFactory);
//const orderElement: UserQueueElement = new UserQueueElement(roomMessageListener, restClient, mobileStyleSheet,
desktopStyleSheet);

roomMessageListener.start();
*/

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import type { User, RoomState, RoomMessage, ServerUploadSongCommand, NextInQueueEvent, MusicStartedEvent, CountingDownEvent, SongUploadTimeoutEvent, UserEnterEvent, UserLeftEvent, SongUploadedEvent } from '../../types.d.ts';
import type { SortableEvent } from 'sortablejs';
import draggable from 'vuedraggable';

const roomId =

const roomState = ref<RoomState>(window.__INITIAL_STATE__);
const songQueue = ref<File[]>([]);
const draggingSong = ref<boolean>(false);
const songDropped = ref<boolean>(false);
const moreThanOneUser = computed(() => roomState.value.userQueue.length > 1);

onMounted(() => {
  const ws = new WebSocket(`wss://${window.location.host}/${roomState.value.roomId}/ws`);
  ws.onmessage = (event) => {
    const roomMessage = JSON.parse(event.data) as RoomMessage
    switch (roomMessage.type) {
      case 'ServerUploadSongCommand':
        const serverUploadSongCommand = roomMessage as ServerUploadSongCommand;
        break;
      case 'NextInQueueEvent':
        const nextInQueueEvent = roomMessage as NextInQueueEvent;
        break;
      case 'MusicStartedEvent':
        const musicStartedEvent = roomMessage as MusicStartedEvent;
        break;
      case 'CountingDownEvent':
        const countingDownEvent = roomMessage as CountingDownEvent;
        break;
      case 'SongUploadedEvent':
        const songUploadedEvent = roomMessage as SongUploadedEvent;
        break;
      case 'SongUploadTimeoutEvent':
        const songUploadTimeoutEvent = roomMessage as SongUploadTimeoutEvent;
        break;
      case 'UserEnterEvent':
        const userEnterEvent = roomMessage as UserEnterEvent;
        roomState.value.userQueue.push(userEnterEvent.user);
        break;
      case 'UserLeftEvent':
        const userLeftEvent = roomMessage as UserLeftEvent
        roomState.value.userQueue = roomState.value.userQueue.filter(user => user.id !== userLeftEvent.userId);
        break;
      default:
        break;
    }
  };
});

const onInputChange = (event: Event) => {
  const input = event.target as HTMLInputElement;
  const files = input.files;
  if (files) {
    songQueue.value.push(
      ...[...Array(files.length).keys()]
        .map(i => files.item(i))
        .filter(file => file !== null)
    );
  }
  input.value = '';
};


const droppable = () => {
  return true;
}

const onDragOver = (event: Event) => {
  if (droppable()) {
    event.preventDefault();
  }
};

const onDragEnter = (event: Event) => {
  if (droppable()) {
    event.preventDefault();
  }
};

const onDrop = (event: Event) => {
  if (draggingSong.value) {
    songDropped.value = true;
  }
};

const onInputClick = (event: Event) => {
};

const onDragEnd = (event: SortableEvent) => {
  if (songDropped.value) {
    songDropped.value = false;
    event.item.parentNode?.removeChild(event.item);
    songQueue.value.splice(event.oldIndex!, 1);
  }
  draggingSong.value = false;
};

const onStartClick = () => {

};

</script>

<template>
  <div
    class="h-screen flex flex-col lg:grid lg:grid-rows-2 lg:grid-cols-2 bg-white dark:bg-black dark:text-white p-4 gap-4">
    <section class="flex-1 flex row-span-2 rounded-lg">
      <ol class="list-none h-full w-full flex lg:flex-col items-center lg:items-start gap-4 p-4 overflow-auto">
        <li v-for="user in roomState.userQueue" :key="user.id"
          class="aspect-square border-2 border-solid border-slate-500 min-w-24 lg:h-32 lg:w-full rounded-lg"
          :style="{ backgroundColor: `#${user.hexColor}` }">
          {{ user.id }}
        </li>
      </ol>
    </section>
    <section class="flex justify-center items-center flex-3 rounded-lg">
      <button v-if="computedOnPageLoad.isCreator" @click="onStartClick" :disabled="!moreThanOneUser"
        class="text-lg md:text-4xl border-4 rounded-lg text-white dark:text-white p-2 md:p-4" :class="{
          'bg-gray-500': !moreThanOneUser,
          'bg-sky-500': moreThanOneUser,
          'cursor-not-allowed': !moreThanOneUser,
          'cursor-pointer': moreThanOneUser
        }">
        Start!
      </button>
    </section>
    <section class="flex-3 gap-8 flex flex-col rounded-lg overflow-hidden">
      <draggable v-if="songQueue.length > 0" :list="songQueue" class="overflow-auto" item-key="name"
        @start="draggingSong = true" @end="onDragEnd">
        <template #item="{ element }">
          <div
            class="w-full flex p-2 justify-between items-center mb-2 overflow-hidden rounded-lg bg-slate-100 h-12 lg:h-16">
            <span class="text-sm overflow-hidden">{{ element.name }}</span>
            <span>=</span>
          </div>
        </template>
      </draggable>
      <label
        class="flex grow min-h-1/4 items-center justify-center caret-transparent bg-linear-to-t to-transparent text-white text-5xl lg:text-8xl"
        :class="{ 'from-red-500': draggingSong, 'from-sky-500': !draggingSong }" contenteditable="true" @keydown.prevent
        @paste.prevent @dragover="onDragOver" @dragenter="onDragEnter" @drop="onDrop" for="song-queue-input">
        {{ draggingSong ? 'x' : '+' }}
        <input id="song-queue-input" ref="song-queue-input" type="file" accept="audio/*" multiple class="hidden"
          @change="onInputChange" @click="onInputClick" />
      </label>
      <!-- Allows clicking the section to add song; only applicable when the list is empty -->
    </section>
  </div>
</template>

<style></style>
