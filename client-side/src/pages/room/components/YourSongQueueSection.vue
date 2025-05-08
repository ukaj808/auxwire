<script lang="ts">
import Sortable from "sortablejs";
import { RestClient } from "../modules/rest-client";
import { SongQueue } from "../modules/song-queue";
import { AuxAudioPlayer } from "../modules/aux-audio-player";
import { LoaderFactory } from "../modules/loader";
import { SvgFactory } from "../modules/svg";
import { RoomMessageListener } from "../modules/room-message-listener";
import { type Song } from "../modules/interface";

export class DropElement {
    private dropSectionEl: HTMLDivElement;
    private roomMessageListener: RoomMessageListener;
    private dropZoneEl: HTMLLabelElement;
    private dropZoneInputEl: HTMLInputElement;
    private dropZonePasteHackInputEl: HTMLInputElement;
    private sortableList: Sortable | undefined;
    private queue: SongQueue;
    private restClient: RestClient;
    private loaderFactory: LoaderFactory;
    private svgFactory: SvgFactory;

    //private onContextMenuBound: (e: MouseEvent) => void;

    constructor(roomMessageListener: RoomMessageListener, restClient: RestClient, loaderFactory: LoaderFactory, svgFactory: SvgFactory) {
        const dropSectionEl = document.getElementById("drop-section");
        if (!dropSectionEl) throw new Error('No drop element found');
        this.dropSectionEl = dropSectionEl as HTMLDivElement;

        const dropZoneEl = document.getElementById("drop-zone");
        if (!dropZoneEl) throw new Error('No drop element found');
        this.dropZoneEl = dropZoneEl as HTMLLabelElement;

        const dropZoneInputEl = document.getElementById("drop-zone-input");
        if (!dropZoneInputEl) throw new Error('No drop element input found');
        this.dropZoneInputEl = dropZoneInputEl as HTMLInputElement;

        const dropZonePasteHackInputEl = document.getElementById("drop-zone-paste-hack");
        if (!dropZonePasteHackInputEl) throw new Error('No drop element input hack found');
        this.dropZonePasteHackInputEl = dropZonePasteHackInputEl as HTMLInputElement;

        this.roomMessageListener = roomMessageListener; 
        this.roomMessageListener.subscribe('ServerUploadSongCommand', () => {
            this.uploadAndDequeueSong();
        });

        this.dropZoneEl.addEventListener('drop', this.onDrop.bind(this));
        this.dropZoneEl.addEventListener('dragover', this.onDragOver.bind(this));
        this.dropZoneEl.addEventListener('paste', this.onPaste.bind(this));
        this.dropZoneEl.addEventListener('keydown', this.onDropzoneKeyDown.bind(this));
        this.dropZoneInputEl.addEventListener('input', this.onInputChange.bind(this));
        this.dropZoneInputEl.addEventListener('click', this.onInputClick.bind(this));
        this.dropZonePasteHackInputEl.addEventListener('focus', this.onHackInputFocus.bind(this));
        this.queue = new SongQueue();
        this.restClient = restClient;
        this.loaderFactory = loaderFactory;
        this.svgFactory = svgFactory;
    }
    
    public async uploadAndDequeueSong() {
        const song = this.queue.peekSong();
        if (song == null) throw new Error('No song found');
        await this.restClient.uploadSong(song);
        return this.dequeueSong();
    }

    /* 
      This is a hack to prevent the user from typing in the dropzone since its contenteditable
      The dropzone is contenteditable so that the user can paste into it
    */
    private onDropzoneKeyDown(e: KeyboardEvent) {
        e.preventDefault();
    }

    /*
      This is hack which enables pasting into the dropzone. Without any input element in the dropzone,
      the paste option isnt available; so I've added an input element which is hidden.
    */
    private onHackInputFocus(e: FocusEvent) {
        e.preventDefault();
        this.dropZoneEl.focus();
    }


    private onPaste(e: ClipboardEvent) {
        e.preventDefault();
        if (e.clipboardData == null) throw new Error('No clipboard data found');
        // check if its a file
        if (e.clipboardData.files.length > 0) {
            [...e.clipboardData.files].forEach((file) => this.addSongToQueue(file));
            return;
        }
        // check if its a url
        let pastedText = e.clipboardData.getData("text");
        if (!this.isValidHttpUrl(pastedText)) return;
        this.addSongToQueue({url: pastedText});
    }

    private isValidHttpUrl(text: string) {
        let url;
        try {
            url = new URL(text);
        } catch (_) {
            return false;  
        }
        return url.protocol === "http:" || url.protocol === "https:";
    }

    private onDrop(e: DragEvent) {
        e.preventDefault();
        // @ts-ignore
        if (e.dataTransfer == null) throw new Error('No data transfer found');
        // Use DataTransferItemList interface to access the file(s)
        [...e.dataTransfer.items].forEach((item, i) => {
            // If dropped items aren't files, reject them
            if (item.kind === "file") {
                const file = item.getAsFile();
                if (file == null) throw new Error('No file found');
                this.addSongToQueue(file);
            }
        });
    }

    private onDragOver(e: Event) {
        // Prevent default behavior (Prevent file from being opened)
        e.preventDefault();
    }

    private onInputChange(e: Event) {
        const inputTarget = e.target as HTMLInputElement;
        const files = inputTarget.files;
        if (files == null) throw new Error('No files found');
        [...files].forEach((file) => this.addSongToQueue(file));
    }

    /*
    * This is a hack to allow the user to upload the same file twice
    * https://stackoverflow.com/questions/12030686/html-input-file-selection-event-not-firing-upon-selecting-the-same-file
    */
    private onInputClick(e: Event) {
        const inputTarget = e.target as HTMLInputElement;
        inputTarget.value = ''; // clear input value
    }

    private addSongToQueue(file: Song) {
        if (this.queue.length === 0) {
            this.initSortableList(file);
        } else {
            this.addSongToSortableList(file);
        }
        this.queue.addSongToQueue(file);
    }

    private dequeueSong() {
        if (this.sortableList == null) throw new Error('No sortable list found');
        if (this.sortableList.el.firstChild == null) throw new Error('No sortable list first child found');
        this.sortableList.el.removeChild(this.sortableList.el.firstChild);
        return this.queue.dequeueSong();
    }

    private shiftToListContain() {
        this.dropZoneEl.classList.add('list-contain');
    }

    private initSortableList(song: Song) {
        this.shiftToListContain();
        const songQueueEl = document.createElement('ol');
        songQueueEl.classList.add('song-queue-list');
        this.sortableList = new Sortable(songQueueEl, {
            handle: '.handle',
        });
        this.clearDropZoneChildrenEls();
        this.dropZoneEl.appendChild(songQueueEl);
        this.addSongToSortableList(song);
    }

    private clearDropZoneChildrenEls() {
        Array.from(this.dropZoneEl.children).forEach((child) => {
            this.dropZoneEl.removeChild(child);
        });
        this.dropZoneEl.appendChild(this.dropZoneInputEl);
    }

    private addSongToSortableList(song: Song) {
        if (this.sortableList == null) throw new Error('No sortable list found');

        const songEl = document.createElement('li');
        const loadingBars = this.loaderFactory.generateSmallLoadingBars();
        songEl.classList.add('song-list-item', 'hidden-edit');

        const songTitleEl = document.createElement('span');
        songTitleEl.classList.add('song-title');
        songEl.appendChild(songTitleEl);

        const dragIcon = this.svgFactory.generateDragIcon();
        dragIcon.classList.add('handle');
        songEl.appendChild(dragIcon);

        if (song instanceof File) {
            songTitleEl.innerText = (song as File).name;
        } else {
            songTitleEl.append(loadingBars);

            this.restClient.validateUrl(song.url).then((title) => {
                songTitleEl.removeChild(loadingBars);
                if (title === "") {
                    song.valid = false;
                    songTitleEl.innerText = "Invalid URL";
                    return;
                }
                song.valid = true;
                songTitleEl.classList.add('text-ellipsis');
                songTitleEl.innerText = title;
            });
        };
        this.sortableList.el.appendChild(songEl);
    }

}
</script>

<template>
</template>

<style scoped>
</style>
