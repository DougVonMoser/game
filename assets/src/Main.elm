module Main exposing (..)

import Browser
import Browser.Dom as Dom
import CodeGiver
import Game
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Http exposing (Error(..))
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import List exposing (..)
import Socket


type alias RoomTypings =
    String


type alias RoomNameTypings =
    String


type alias MyHash =
    PlayerHash


type Model
    = ChoosingHowToStartGame (Maybe Room) RoomTypings RoomNameTypings MyHash
    | InLobby Room (List Player)
    | InGame Room Game.Model
    | InCodeGiver Room CodeGiver.Model


init meHash =
    let
        ignoreme =
            Debug.log "wtf" meHash
    in
    ( ChoosingHowToStartGame Nothing "" "" (PlayerHash meHash), Cmd.none )


type Room
    = Room String


type Msg
    = ServerSentData D.Value
    | PresenceState (List Player)
    | UserClickedStartCardGame --| ServerSentLatestCards
    | UserClickedCreateNewGame
    | UserClickedImNotAnAdmin
    | UserClickedImAnAdmin
    | UserClickedImInTheWrongGame
    | GotCodeGiverMsg CodeGiver.AdminMsg
    | GotGameMsg Game.Msg
    | JoinedDifferentRoom Room
    | UserTypedRoomToEnter String
    | UserTypedTheirName String
    | UserClickedJoinGame
    | NOOP


type Player
    = Player String PlayerHash
    | Me String PlayerHash


isThisPlayer : Player -> Player -> Bool
isThisPlayer player1 player2 =
    getPlayerHash player1 == getPlayerHash player2


getPlayerHash player =
    case player of
        Player _ (PlayerHash hash) ->
            hash

        Me _ (PlayerHash hash) ->
            hash


flip f y x =
    f x y


playerDecoder : ( String, String ) -> Player
playerDecoder ( id, name ) =
    Player name (PlayerHash id)


getPlayerName : Player -> String
getPlayerName player =
    case player of
        Player name _ ->
            name

        Me name _ ->
            name


playersDecoder =
    D.keyValuePairs (D.field "name" D.string)
        |> D.map (List.map playerDecoder)


presenceStateDecoder =
    D.field "value" playersDecoder


presenceDiffDecoder =
    D.field "value"
        (D.field "leaves" playersDecoder
            |> D.andThen
                (\x ->
                    case x of
                        onlyOnePlayer :: [] ->
                            D.succeed onlyOnePlayer

                        _ ->
                            D.fail "COULLLDJFLSK"
                )
        )


type PlayerHash
    = PlayerHash String


update msg model =
    case msg of
        NOOP ->
            ( model, Cmd.none )

        PresenceState playerList ->
            case model of
                InLobby room existingPlayersIfAny ->
                    ( InLobby room playerList, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserTypedRoomToEnter s ->
            case model of
                ChoosingHowToStartGame maybeRoom roomTypings roomNameTypings meHash ->
                    ( ChoosingHowToStartGame maybeRoom (String.toUpper s) roomNameTypings meHash, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserTypedTheirName s ->
            case model of
                ChoosingHowToStartGame maybeRoom roomTypings roomNameTypings meHash ->
                    ( ChoosingHowToStartGame maybeRoom roomTypings s meHash, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        JoinedDifferentRoom room ->
            ( InLobby room [], Cmd.none )

        UserClickedStartCardGame ->
            ( model
            , Socket.toSocket <|
                E.object
                    [ ( "action", E.string "elmSaysStartCardGame" )
                    ]
            )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    ( ChoosingHowToStartGame Nothing "" "" (PlayerHash "SHIT"), Socket.joinLobby <| E.string "joindatlobby" )

        UserClickedImAnAdmin ->
            case model of
                InGame room gameModel ->
                    ( InCodeGiver room { cards = gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserClickedImNotAnAdmin ->
            case model of
                InCodeGiver room gameModel ->
                    let
                        initModel =
                            Game.initModel
                    in
                    ( InGame room { initModel | cards = gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ServerSentData x ->
            case model of
                ChoosingHowToStartGame (Just room) _ _ _ ->
                    ( InLobby room [], Cmd.none )

                InLobby room _ ->
                    let
                        ( gameModel, cmd ) =
                            Game.decodeCardsFromServer Game.initModel x
                    in
                    ( InGame room gameModel, Cmd.map GotGameMsg cmd )

                _ ->
                    ( model, Cmd.none )

        UserClickedJoinGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings roomNameTypings meHash ->
                    ( ChoosingHowToStartGame Nothing roomTypings roomNameTypings meHash
                    , Socket.toSocket <|
                        E.object
                            [ ( "action", E.string "elmSaysJoinExistingRoom" )
                            , ( "room", E.string roomTypings )
                            , ( "name", E.string roomNameTypings )
                            ]
                    )

                _ ->
                    ( model, Cmd.none )

        UserClickedCreateNewGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings roomNameTypings meHash ->
                    ( ChoosingHowToStartGame Nothing roomTypings roomNameTypings meHash
                    , Socket.toSocket <|
                        E.object
                            [ ( "action", E.string "elmSaysCreateNewRoom" )
                            , ( "name", E.string roomNameTypings )
                            ]
                    )

                _ ->
                    ( model, Cmd.none )

        GotCodeGiverMsg msgCG ->
            case model of
                InCodeGiver room modelCG ->
                    let
                        ( newModelCG, newCmdCG ) =
                            CodeGiver.update msgCG modelCG
                    in
                    ( InCodeGiver room newModelCG, Cmd.map GotCodeGiverMsg newCmdCG )

                _ ->
                    ( model, Cmd.none )

        GotGameMsg msgGAME ->
            case model of
                InGame room modelGAME ->
                    let
                        ( newModelGAME, newCmdGAME ) =
                            Game.update msgGAME modelGAME
                    in
                    ( InGame room newModelGAME, Cmd.map GotGameMsg newCmdGAME )

                _ ->
                    ( model, Cmd.none )


view model =
    div []
        [ toolbarView model
        , bodyView model
        ]


toolbarView : Model -> Html Msg
toolbarView model =
    case model of
        ChoosingHowToStartGame _ _ _ _ ->
            text ""

        InLobby (Room room) playerSet ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImAnAdmin ] [ text "Code Giver View" ]

                --, button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        InGame (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImAnAdmin ] [ text "Code Giver View" ]

                --, button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        InCodeGiver (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImNotAnAdmin ] [ text "Audience View" ]

                --, button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]


bodyView : Model -> Html Msg
bodyView model =
    case model of
        ChoosingHowToStartGame maybeRoom roomTypings roomNameTypings meHash ->
            div [ class "home-container" ]
                [ div [ class "join" ]
                    [ h1 [] [ text "Game Code" ]
                    , input [ class "home-input", placeholder "Enter 4-Letter Code", onInput UserTypedRoomToEnter, maxlength 4, value roomTypings ] []
                    ]
                , div [ class "join" ]
                    [ h1 [] [ text "Name" ]
                    , input [ class "home-input", placeholder "Enter your name here", onInput UserTypedTheirName, maxlength 20, value roomNameTypings ] []
                    ]
                , div [ class "create" ]
                    [ joinButton roomTypings
                    ]
                , div [ class "gif" ] [ img [ src "https://s3.amazonaws.com/dougvonmoser.com/commonplace.gif" ] [] ]
                ]

        InLobby room playerList ->
            div []
                [ h1 [] [ text "LOBBY" ]
                , playerGridView playerList
                , button [ onClick UserClickedStartCardGame ] [ text "START CARD GAME" ]
                ]

        InCodeGiver _ codeGiverModel ->
            Html.map GotCodeGiverMsg <| CodeGiver.view codeGiverModel

        InGame _ gameModel ->
            Html.map GotGameMsg <| Game.view gameModel


playerGridView playerList =
    let
        f =
            div [] << List.singleton << text << getPlayerName
    in
    div [] <| List.map f playerList


joinButton roomTypings =
    let
        isDisabled =
            String.length roomTypings /= 4

        ( disabledClass, disabledText, onClickAction ) =
            if isDisabled then
                ( "", "Create New Game", UserClickedCreateNewGame )

            else
                ( "", "Join game ->", UserClickedJoinGame )
    in
    button [ onClick onClickAction, class ("join-button" ++ disabledClass) ] [ text disabledText ]


main : Program String Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Game"
                , body = [ view m ]
                }
        , subscriptions = subscriptions
        }



-- socketHandler has to decode the {type: "action", value: [{stuff: things}]}


socketHandler : Model -> D.Value -> Msg
socketHandler model rawAction =
    case D.decodeValue (D.field "type" D.string) rawAction of
        Ok val ->
            case val of
                "latestCards" ->
                    case D.decodeValue (D.field "value" D.value) rawAction of
                        Ok rawValue ->
                            case model of
                                InCodeGiver _ _ ->
                                    GotCodeGiverMsg (CodeGiver.Hey rawValue)

                                InGame _ _ ->
                                    GotGameMsg (Game.ReceivedCardsFromServer rawValue)

                                ChoosingHowToStartGame _ _ _ _ ->
                                    ServerSentData rawValue

                                InLobby _ _ ->
                                    ServerSentData rawValue

                        Err _ ->
                            NOOP

                "presence_state" ->
                    case D.decodeValue presenceStateDecoder rawAction of
                        Ok playerList ->
                            PresenceState playerList

                        Err _ ->
                            NOOP

                "presence_diff" ->
                    case model of
                        InLobby room playerList ->
                            case D.decodeValue presenceDiffDecoder rawAction of
                                Ok player ->
                                    PresenceState <|
                                        List.filter (not << isThisPlayer player) playerList

                                Err e ->
                                    -- this gets hit when the diff is anything but one player leaving
                                    NOOP

                        _ ->
                            NOOP

                _ ->
                    NOOP

        Err _ ->
            NOOP


roomDecoding raw =
    case D.decodeValue (D.map Room (D.field "room" D.string)) raw of
        Ok val ->
            JoinedDifferentRoom val

        Err _ ->
            JoinedDifferentRoom <| Room "ERROR"


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        sockets =
            [ Socket.fromSocket (socketHandler model)
            , Socket.joinedDifferentRoom roomDecoding
            ]
    in
    case model of
        ChoosingHowToStartGame _ _ _ _ ->
            Sub.batch sockets

        InGame _ gameModel ->
            Sub.batch <|
                sockets
                    ++ [ Sub.map GotGameMsg (Game.subscriptions gameModel)
                       ]

        _ ->
            Sub.batch sockets



-- DECODERS
