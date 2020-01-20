'use strict';

require("./styles.scss");

 import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})
socket.connect()

const Main = require('./Main.elm');
let app = Main.Elm.Main.init({});


let channel = socket.channel("room:lobby", {});
channel.join()
  .receive("ok", resp => {
        console.log("just joined lobby, got from server")
        console.log(resp)
  })

function joinLobby (channel) {
    console.log("joinLobby function")
    channel = socket.channel("room:lobby", {});
    channel.join()
      .receive("ok", resp => {
            console.log("just joined lobby, got from server")
            console.log(resp)
      })
      .receive("error", resp => { console.log("Unable to join", resp) })
}

function joinGameRoom (channel, msg) {
    console.log("channel replying with new game starting ")
    console.log(msg)
    channel = socket.channel("room:" + msg.room)
    channel.join()
   .receive("ok", resp => {
        console.log("just joined, got from server")
        console.log(resp)
        app.ports.fromSocket.send(resp)
    })   
    channel.on("updateFromServer", msg => {
        console.log("updateFromServer got ")
        console.log(msg.cards)
        app.ports.fromSocket.send(msg.cards)
    })
}

channel.on("channelReplyingWithNewGameStarting", msg => {
    console.log("channelReplyingWithNewGameStarting")
    joinGameRoom(channel, msg)
})


app.ports.alsoToSocket.subscribe(message => {
    console.log("sending the click and hash to server")
    channel.push("clicked", {body: message})
})


app.ports.toSocket.subscribe(message => {
    console.log("trying to do create new room")
    channel.push("elmSaysCreateNewRoom", {})
})

//channel.push("restart", {})
