'use strict';

require("./styles.scss");

import socket from "./socket"
import { bind } from "./webSocket.js"


const {Elm} = require('./Main');
var app = Elm.Main.init({flags: 6});

bind(app)

