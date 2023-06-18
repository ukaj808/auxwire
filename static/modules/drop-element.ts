import Sortable from "sortablejs";
import { RestClient } from "./rest-client";
import { SongQueue } from "./song-queue";
import { AuxAudioPlayer } from "./aux-audio-player";

export class DropElement {
    el: HTMLDivElement;
    dropZoneEl: HTMLLabelElement;
    dropZoneInputEl: HTMLInputElement;
    sortableList: Sortable | undefined;
    queue: SongQueue;
    restClient: RestClient;
    auxAudioPlayer: AuxAudioPlayer;

    constructor(restClient: RestClient, auxAudioPlayer: AuxAudioPlayer) {
        const el = document.getElementById("drop");
        if (!el) throw new Error('No drop element found');
        this.el = el as HTMLDivElement;

        const dropZoneEl = document.getElementById("drop-zone");
        if (!dropZoneEl) throw new Error('No drop element found');
        this.dropZoneEl = dropZoneEl as HTMLLabelElement;

        const dropZoneInputEl = document.getElementById("drop-zone-input");
        if (!dropZoneInputEl) throw new Error('No drop element input found');
        this.dropZoneInputEl = dropZoneInputEl as HTMLInputElement;

        this.dropZoneEl.addEventListener('drop', this.onDrop.bind(this));
        this.dropZoneEl.addEventListener('dragover', this.onDragOver.bind(this));
        this.dropZoneInputEl.addEventListener('input', this.onInputChange.bind(this));
        this.dropZoneInputEl.addEventListener('click', this.onInputClick.bind(this));
        this.queue = new SongQueue();
        this.restClient = restClient;
        this.auxAudioPlayer = auxAudioPlayer;
    }
    
    public async uploadAndDequeueSong() {
        const song = this.queue.peekSong();
        if (song == null) throw new Error('No song found');
        await this.restClient.uploadSong(song);
        return this.dequeueSong();
    }

    private onAudioEvent(event: AudioEvent) {
       // possibly needed??
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
                console.log(`… file[${i}].name = ${file.name}`);
                this.addSongToQueue(file);
            }
        });
    }

    private onDragOver(e: Event) {
        // Prevent default behavior (Prevent file from being opened)
        console.log('drag over');
        e.preventDefault();
    }

    private onInputChange(e: Event) {
        const inputTarget = e.target as HTMLInputElement;
        const files = inputTarget.files;
        if (files == null) throw new Error('No files found');
        console.log('input change', files);
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

    private addSongToQueue(file: File) {
        console.log('adding song to queue', file);  
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

    private initSortableList(file: File) {
        this.shiftToListContain();
        const songQueueEl = document.createElement('ol');
        songQueueEl.classList.add('song-queue-list');
        this.sortableList = new Sortable(songQueueEl, {});
        this.clearDropZoneChildrenEls();
        this.dropZoneEl.appendChild(songQueueEl);
        this.addSongToSortableList(file);
    }

    private clearDropZoneChildrenEls() {
        Array.from(this.dropZoneEl.children).forEach((child) => {
            if (child === this.dropZoneInputEl) return;
            this.dropZoneEl.removeChild(child);
        });
    }

    private addSongToSortableList(file: File) {
        if (this.sortableList == null) throw new Error('No sortable list found');
        console.log('adding song to sortable list', file);
        const songEl = document.createElement('li');
        songEl.classList.add('song-list-item');
        songEl.innerText = file.name;
        this.sortableList.el.appendChild(songEl);
    }

}
