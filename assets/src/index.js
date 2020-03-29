'use strict';

require("./styles.scss");
import 'babel-polyfill';

import {Socket} from "phoenix"
import bindMedia from "./media.js"
import findOrCreateUserToken from "./uuid.js"

import "./customComponents.js"


const global_user_token = findOrCreateUserToken()

let socket = new Socket("/socket", {params: {token: global_user_token}})
socket.connect()

const Main = require('./Main.elm');
console.log(global_user_token)
let app = Main.Elm.Main.init({flags: global_user_token});


let channel = socket.channel("room:lobby", {token: global_user_token});
channel.join()
  .receive("ok", resp => {
        //console.log("just joined lobby, got from server")
        //console.log(resp)
  })
reListenForUpdates()

function reListenForUpdates () {
    channel.on("signalToStartGameWithCards", msg => {
        //console.log("updateFromServer got ")
        //console.log(msg.cards)
        app.ports.fromSocket.send({type: "latestCards", value: msg.cards})
    })    
    channel.on("updateFromServer", msg => {
        //console.log("updateFromServer got ")
        //console.log(msg.cards)
        app.ports.fromSocket.send({type: "latestCards", value: msg.cards})
    })
    channel.on("channelReplyingWithNewGameStarting", msg => {
        //console.log("channelReplyingWithNewGameStarting")
        joinGameRoom(msg)
    })
    channel.on("presence_diff", msg => {
        // ignoring for now, broadcasting full new presences
        // each time someone joins. 
        //
        console.log(" i guess this is a presence diff")
        console.log(msg)
        app.ports.fromSocket.send({type: "presence_diff", value: msg})
    })
    channel.on("presence_state", msg => {
        console.log(" i guess this is a presence state")
        app.ports.fromSocket.send({type: "presence_state", value: msg})
        console.log(msg)
    })
}

function joinLobby () {
    //console.log("joinLobby function")
    channel = socket.channel("room:lobby", {token: global_user_token});
    channel.join()
      .receive("ok", resp => {
            //console.log("just joined lobby, got from server")
            //console.log(resp)
      })
      .receive("error", resp => { console.log("Unable to join", resp) })
    reListenForUpdates()
}

function createGameRoom (name) {
    let room = generateRoomName();
    channel = socket.channel("room:" + room, {name: name, token: global_user_token})
    channel.join()
   .receive("ok", resp => {
        //console.log("successfully joined new channel, got from server")
        //console.log(resp)
        app.ports.joinedDifferentRoom.send({room : room})
    })   
    reListenForUpdates()
}


function joinGameRoom (room, playerName) {
    //console.log("channel replying with new game starting ")
    //console.log(msg)
    channel = socket.channel("room:" + room, {name: playerName, token: global_user_token})
    channel.join()
   .receive("ok", resp => {
        //console.log("successfully joined new channel, got from server")
        //console.log(resp)
        app.ports.joinedDifferentRoom.send({name: playerName, room : room})
    })   
    reListenForUpdates()
}

app.ports.joinLobby.subscribe(message => {
    //console.log("joining the lobby again")
    joinLobby()
})


app.ports.restartGameSameRoom.subscribe(message => {
    //console.log("trying to restart the game but staying in this room")
    channel.push("restart", {})
})


app.ports.alsoToSocket.subscribe(message => {
    //console.log("sending the click and hash to server")
    channel.push("clicked", {body: message})
})


app.ports.toSocket.subscribe(message => {
    if (message.action == "elmSaysCreateNewRoom"){
        //console.log("trying to do create new room")
        createGameRoom(message.name)
        //channel.push("elmSaysCreateNewRoom", {name: message.room})
    } else if (message.action == "elmSaysJoinExistingRoom") {
        //console.log("trying to do join existing room", message.room)
        joinGameRoom(message.room, message.name)
    } else if (message.action == "elmSaysStartCardGame") {
        channel.push("elmSaysStartCardGame", {})
    } else if (message.action == "elmSaysConnectMedia") {
        bindMedia();
    }
})

//channel.push("restart", {})
function generateRoomName(length) {
   var result           = '';
   var characters       = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
   var charactersLength = characters.length;
   for ( var i = 0; i < 4; i++ ) {
      result += characters.charAt(Math.floor(Math.random() * charactersLength));
   }
   return result;
}






//page navigation away warning
// window.onbeforeunload = function() {
//     return true;
// };
