import { AuxAudioPlayer } from "../modules/aux-audio-player";
import { RoomMessageListener } from "../modules/room-message-listener";
import { OrderElement } from "../modules/order-element";
import { DropElement } from "../modules/drop-element"; 
import { CurrentlyPlayingElement } from "../modules/currently-playing-element";
import { RestClient } from "../modules/rest-client";
import { SvgFactory } from "../modules/svg";
import { SongQueue } from "../modules/song-queue";
import { RoomMessagePublisher } from "../modules/room-message-publisher";

let roomId: string    = location.pathname.substr(1);
let listening: boolean = false;

const svgFactory: SvgFactory = new SvgFactory();
const auxAudioPlayer: AuxAudioPlayer = new AuxAudioPlayer(roomId);
const restClient: RestClient = new RestClient(roomId);
const orderElement: OrderElement = new OrderElement(restClient, svgFactory);
const currentlyPlayingElement: CurrentlyPlayingElement 
    = new CurrentlyPlayingElement(auxAudioPlayer);
const dropElement: DropElement = new DropElement(restClient, auxAudioPlayer);
const roomMessagePublisher = new RoomMessagePublisher();
const roomMessageListener: RoomMessageListener = new RoomMessageListener(
    roomId,
    orderElement,
    dropElement,
    restClient,
    auxAudioPlayer
);
roomMessageListener.start();