'use strict';

require("./styles.scss");

 import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

export default socket


const {Elm} = require('./Main');
var app = Elm.Main.init({flags: 6});


app.ports.toSocket.subscribe(message => {
    if (message == "connect") {
        socket.connect()

        let channel = socket.channel("room:lobby", {})
        channel.join()
          .receive("ok", resp => {
                console.log("got from server")
                console.log(resp)
                app.ports.fromSocket.send(resp)
          })
          .receive("error", resp => { console.log("Unable to join", resp) })

        channel.on("updateFromServer", msg => {
            console.log("got from server")
            console.log(msg)
        })

    }
})
