'use strict';

require("./styles.scss");

 import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

let app;
const Game = require('./Game.elm');
const CodeGiver = require('./CodeGiver.elm');
if (window.location.href.includes("admin")) {
    app = CodeGiver.Elm.CodeGiver.init({});
} else {
    app = Game.Elm.Game.init({});
}

let channel;

app.ports.toSocket.subscribe(message => {
    if (message == "connect") {
        socket.connect()

        channel = socket.channel("room:lobby", {})
        channel.join()
          .receive("ok", resp => {
                console.log("got from server")
                console.log(resp)
                app.ports.fromSocket.send(resp)
          })
          .receive("error", resp => { console.log("Unable to join", resp) })

        channel.on("updateFromServer", msg => {
            console.log("got from server")
            console.log(msg.cards)
            app.ports.fromSocket.send(msg.cards)
        })

    } else if (message == "restart"){
        channel.push("restart", {})
    } else {
        // assume its a clicked card for now :)
        channel.push("clicked", {body: message})
        
    }
    
})
