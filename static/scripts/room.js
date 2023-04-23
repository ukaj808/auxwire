// Global
const roomId = location.pathname.substr(1);
const wsProtocol = (location.protocol != null && location.protocol === "https:") ? "wss" : "ws";
const roomsUrl = (location.protocol != null && location.protocol === "https:") ? "augslink-rooms.deno.dev" : "localhost:8080";
const roomMainElement = document.getElementById("room");
let userId;
let userName;
let musicEnabled = false;
let musicWs;

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// Util
// Workaround for the fact that js/ts can't serialize/deserialize maps
const reviver = (key, value) => {
    if(typeof value === 'object' && value !== null) {
        if (value.dataType === 'Map') {
            return new Map(value.value);
        }
    }
    return value;
}
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//

// Order
const createNewUserListElement = (userDetails) => {
    const li = document.createElement('li');
    li.id = userDetails.userId;
    li.class
    li.className = 'full-flex section centered tertiary-theme';

    const uname = document.createElement('span');
    uname.textContent = userDetails.userName;
    uname.classList.add('user-order-list__username-lbl');

    li.appendChild(uname);

    return li;
}
//
//
//
//
//
//
//
//
//roomElement
//
//
//
//
//
//
//
//
//
//
//
//
//

// Current
const currentElement = document.getElementById("current");

const concatFloat32Arrays = (arr1, arr2) => {
  const out = new Float32Array(arr1.length + arr2.length);
  out.set(arr1);
  out.set(arr2, arr1.length);
  return out;
}

const connectToMusic = async () => {
    if (musicWs) throw Error('Invalid state; Already connected to music');
    musicEnabled = true;
    musicWs = new WebSocket(`${wsProtocol}://${roomsUrl}/${roomId}/${userId}/music/listen`);
    musicWs.binaryType = 'arraybuffer';

    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const audioBufferNode = audioContext.createBuffer(1, 44100, 44100);
    const source = audioContext.createBufferSource();
    source.buffer = audioBufferNode;
    source.connect(audioContext.destination);
    source.start();
    
    musicWs.addEventListener("message", (event) => {
        const rawData = new Float32Array(event.data);
        audioBufferNode.copyToChannel(rawData, 0);
        console.log('Audio buffer:', source.context.currentTime);
        console.log('Audio context state: ', audioContext.state);
        console.log('Audio buffer source node playback state: ', source.playbackRate);
    });


}
const disconnectMusic = () => {
    if (!musicWs) throw Error('Invalid state; Cant disconnect music ws if it doesnt exist');
    musicEnabled = false;
    musicWs.close();
    musicWs = undefined;
}

const currentClickHandler = () => {
    if (!musicEnabled) connectToMusic();
    else disconnectMusic();
}

currentElement.addEventListener("click", currentClickHandler);
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//

// Drop

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//



// Room
const publishRoomEvent = (e) => roomMainElement.dispatchEvent(e);
const createUserWelcomeEvent = (eventData) => new CustomEvent('server-welcome',
    {detail: {userId: eventData.userId, userName: eventData.userName}});
const createUserEnterEvent = (eventData) => new CustomEvent('user-enter',
    {detail: {userId: eventData.userId, userName: eventData.userName}});
const createUserLeftEvent = (eventData) => new CustomEvent('user-left',
    {detail: {userId: eventData.userId}});
const createAndPublishServerWelcomeMessage = (eventData) => publishRoomEvent(createUserWelcomeEvent(eventData));
const createAndPublishUserEnterEvent = (eventData) => publishRoomEvent(createUserEnterEvent(eventData));
const createAndPublishUserLeftEvent = (eventData) => publishRoomEvent(createUserLeftEvent(eventData));

const roomMessageHandler = ({data}) => {
    console.log(data);
    let parsedData = JSON.parse(data, reviver);

    switch (parsedData?.type) {
        case "ServerWelcomeMessage":
            createAndPublishServerWelcomeMessage(parsedData);
            break;
        case "UserEnterEvent":
            createAndPublishUserEnterEvent(parsedData);
            break;
        case "UserLeftEvent":
            createAndPublishUserLeftEvent(parsedData);
            break;
        default:
            console.error("Unrecognized Event!");
            break;
    }
}

const onUserWelcome = ({detail}) => {
    document.getElementById("user-order-list").appendChild(createNewUserListElement(detail));
    userId = detail.userId;
    userName = detail.userName;
}

const onUserJoin = ({detail}) => {
    document.getElementById("user-order-list").appendChild(createNewUserListElement(detail));
}

const onUserLeft = ({detail}) => {
    const userId = detail.userId;
    const li = document.getElementById(userId);
    li.remove();
}

const roomElement = document.getElementById("room");

roomElement.addEventListener("server-welcome", onUserWelcome);
roomElement.addEventListener("user-enter", onUserJoin);
roomElement.addEventListener("user-left", onUserLeft);

const connectToRoom = () => {
    let ws;
    if (ws) ws.close();
    ws = new WebSocket(`${wsProtocol}://${roomsUrl}/${roomId}/${wsProtocol}`);
    ws.addEventListener("message", roomMessageHandler);
};

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
// Connect to web socket AFTER all the room modules have loaded (e.g. Order Section)
// Each module adds event listeners to the room page (main)...
// If the websocket connection happens before the event listeners are added in each module
// then those modules won't know that they/or another user joined...
// Still noticing this bug in prod!!
window.addEventListener('load', connectToRoom)
