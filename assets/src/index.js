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
        console.log("just joined, got from server")
        console.log(resp)
        // this is just a hello message for now
        //app.ports.fromSocket.send(resp)
  })
  .receive("error", resp => { console.log("Unable to join", resp) })


channel.on("channelReplyingWithNewGameStarting", msg => {
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
})


app.ports.alsoToSocket.subscribe(message => {
    console.log("also trying to do stuff")
    // assume its a clicked card for now :)
    channel.push("clicked", {body: message})
        
    
})


app.ports.toSocket.subscribe(message => {
    console.log("trying to do create new room")
    channel.push("elmSaysCreateNewRoom", {})
    
})

//channel.push("restart", {})
//channel.push("clicked", {body: message})
