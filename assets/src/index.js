'use strict';

require("./styles.scss");

import {Socket} from "phoenix"
import findOrCreateUserToken from "./uuid.js"

const global_user_token = findOrCreateUserToken()

let socket = new Socket("/socket", {params: {token: global_user_token}})
socket.connect()

const Main = require('./Main.elm');
let app = Main.Elm.Main.init({});


let channel = socket.channel("room:lobby", {token: global_user_token});
channel.join()
  .receive("ok", resp => {
        //console.log("just joined lobby, got from server")
        //console.log(resp)
  })
reListenForUpdates()

function reListenForUpdates () {
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
        console.log(" i guess this is a presence diff")
        app.ports.fromSocket.send({type: "presence_diff", value: msg})
        console.log(msg)
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

function joinGameRoom (msg) {
    //console.log("channel replying with new game starting ")
    //console.log(msg)
    channel = socket.channel("room:" + msg.room, {token: global_user_token})
    channel.join()
   .receive("ok", resp => {
        //console.log("successfully joined new channel, got from server")
        //console.log(resp)
        app.ports.joinedDifferentRoom.send({room : msg.room})
        app.ports.fromSocket.send({type: "latestCards", value: resp})
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
        channel.push("elmSaysCreateNewRoom", {})
    } else if (message.action == "elmSaysJoinExistingRoom") {
        //console.log("trying to do join existing room", message.room)
        channel.push("elmSaysJoinExistingRoom", {room: message.room})
    }

})

//channel.push("restart", {})
