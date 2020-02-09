port module Socket exposing (..)

import Json.Decode as D
import Json.Encode as E


port toSocket : E.Value -> Cmd msg


port joinLobby : E.Value -> Cmd msg


port fromSocket : (D.Value -> msg) -> Sub msg


port joinedDifferentRoom : (D.Value -> msg) -> Sub msg


port alsoToSocket : E.Value -> Cmd msg
