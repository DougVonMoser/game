port module Socket exposing (..)

import Json.Decode as D
import Json.Encode as E



--type EventsElmCanEmit
--    = CreateNewRoom
--    | JoinExistingRoom
--    | ReturnToWelcomeScreen
--    | ClickedHash


port toSocket : E.Value -> Cmd msg


elmSaysStartCardGame =
    toSocket <|
        E.object
            [ ( "action"
              , E.string "elmSaysStartCardGame"
              )
            ]


elmSaysJoinExistingRoom roomTypings =
    toSocket <|
        E.object
            [ ( "action", E.string "elmSaysJoinExistingRoom" )
            , ( "room", E.string roomTypings )
            ]


elmSaysCreateNewRoom =
    toSocket <|
        E.object
            [ ( "action", E.string "elmSaysCreateNewRoom" )
            ]


port joinLobby : E.Value -> Cmd msg


port fromSocket : (D.Value -> msg) -> Sub msg


port notBeingUsed : (String -> msg) -> Sub msg


port joinedDifferentRoom : (D.Value -> msg) -> Sub msg


port alsoToSocket : E.Value -> Cmd msg


port restartGameSameRoom : E.Value -> Cmd msg
