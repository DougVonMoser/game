module Main exposing (..)

import Animator
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


type Model
    = ChoosingHowToStartGame (Maybe Room) RoomTypings
    | InLobby Room
    | InGame Room Game.Model
    | InCodeGiver Room CodeGiver.Model


init _ =
    ( ChoosingHowToStartGame Nothing "", Cmd.none )


type Room
    = Room String


type Msg
    = ServerSentData D.Value
    | UserClickedCreateNewGame
    | UserClickedImNotAnAdmin
    | UserClickedImAnAdmin
    | UserClickedImInTheWrongGame
    | UserClickedConnectMedia
    | GotCodeGiverMsg CodeGiver.AdminMsg
    | GotGameMsg Game.Msg
    | JoinedARoom Room
    | UserTypedRoomToEnter String
    | UserTypedTheirName String
    | UserClickedJoinGame
    | NOOP


type alias Name =
    String


type Player
    = Player Name PlayerHash
    | Me Name PlayerHash


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
            name ++ " (You)"


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

        UserTypedRoomToEnter s ->
            case model of
                ChoosingHowToStartGame maybeRoom roomTypings ->
                    ( ChoosingHowToStartGame maybeRoom (String.toUpper s), Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserTypedTheirName s ->
            case model of
                ChoosingHowToStartGame maybeRoom roomTypings ->
                    ( ChoosingHowToStartGame maybeRoom roomTypings, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        JoinedARoom room ->
            case model of
                ChoosingHowToStartGame _ _ ->
                    ( InLobby room
                    , Socket.toSocket <|
                        E.object [ ( "action", E.string "elmSaysStartCardGame" ) ]
                    )

                _ ->
                    ( model, Cmd.none )

        UserClickedConnectMedia ->
            ( model
            , Socket.toSocket <| E.object [ ( "action", E.string "elmSaysConnectMedia" ) ]
            )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    ( ChoosingHowToStartGame Nothing "", Socket.joinLobby <| E.string "joindatlobby" )

        UserClickedImAnAdmin ->
            case model of
                InGame room gameModel ->
                    ( InCodeGiver room { cards = List.map Animator.current gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserClickedImNotAnAdmin ->
            case model of
                InCodeGiver room gameModel ->
                    let
                        initModel =
                            Game.initModel

                        model2 =
                            Game.doTheThing initModel gameModel.cards
                    in
                    ( InGame room model2, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ServerSentData x ->
            case model of
                ChoosingHowToStartGame (Just room) _ ->
                    ( InLobby room, Cmd.none )

                InLobby room ->
                    let
                        gameModel =
                            Game.decodeCardsFromServer Game.initModel x
                    in
                    ( InGame room gameModel, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        UserClickedJoinGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings ->
                    ( ChoosingHowToStartGame Nothing roomTypings
                    , Socket.toSocket <|
                        E.object
                            [ ( "action", E.string "elmSaysJoinExistingRoom" )
                            , ( "room", E.string roomTypings )
                            ]
                    )

                _ ->
                    ( model, Cmd.none )

        UserClickedCreateNewGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings ->
                    ( ChoosingHowToStartGame Nothing roomTypings
                    , Socket.toSocket <|
                        E.object
                            [ ( "action", E.string "elmSaysCreateNewRoom" )
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
        InGame (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImAnAdmin ] [ text "Code Giver View" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        InCodeGiver (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImNotAnAdmin ] [ text "Audience View" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        _ ->
            text "oops"


bodyView : Model -> Html Msg
bodyView model =
    case model of
        ChoosingHowToStartGame maybeRoom roomTypings ->
            div [ class "home-container" ]
                [ div [ class "join" ]
                    [ h1 [] [ text "Game Code" ]
                    , input [ class "home-input", placeholder "Enter 4-Letter Code", onInput UserTypedRoomToEnter, maxlength 4, value roomTypings ] []
                    ]
                , div [ class "create" ]
                    [ joinButton roomTypings
                    ]
                , div [ class "gif" ] [ img [ src "https://s3.amazonaws.com/dougvonmoser.com/commonplace.gif" ] [] ]
                ]

        InLobby room ->
            text "LOBBY"

        InCodeGiver _ codeGiverModel ->
            Html.map GotCodeGiverMsg <| CodeGiver.view codeGiverModel

        InGame _ gameModel ->
            Html.map GotGameMsg <| Game.view gameModel


playerGridView player =
    case player of
        Player name playerHash ->
            div [ class "player-row" ] [ text name ]

        Me name playerHash ->
            div [ class "player-row" ]
                [ node "local-media"
                    [ class "local-media"

                    -- could be used for player hash specific events
                    , Html.Attributes.attribute "data-tester" "test-hash-lalalala"
                    ]
                    []
                , text <| name ++ " (You)"
                ]


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

                                ChoosingHowToStartGame _ _ ->
                                    ServerSentData rawValue

                                InLobby _ ->
                                    ServerSentData rawValue

                        Err _ ->
                            NOOP

                _ ->
                    NOOP

        Err _ ->
            NOOP


roomDecoding raw =
    case D.decodeValue (D.map Room (D.field "room" D.string)) raw of
        Ok val ->
            JoinedARoom val

        Err _ ->
            JoinedARoom <| Room "ERROR"


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        sockets =
            [ Socket.fromSocket (socketHandler model)
            , Socket.joinedDifferentRoom roomDecoding
            ]
    in
    case model of
        ChoosingHowToStartGame _ _ ->
            Sub.batch sockets

        InGame _ gameModel ->
            Sub.batch <|
                sockets
                    ++ [ Sub.map GotGameMsg (Game.subscriptions gameModel)
                       ]

        _ ->
            Sub.batch sockets



-- DECODERS
