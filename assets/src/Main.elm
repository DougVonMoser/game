port module Main exposing (..)

import Browser
import Browser.Dom as Dom
import CodeGiver
import Game
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)


port toSocket : E.Value -> Cmd msg


port joinLobby : E.Value -> Cmd msg


port fromSocket : (D.Value -> msg) -> Sub msg


port joinedDifferentRoom : (D.Value -> msg) -> Sub msg


type Model
    = ChoosingHowToStartGame (Maybe Room)
    | InGame Room Game.Model
    | InCodeGiver Room CodeGiver.Model


init _ =
    ( ChoosingHowToStartGame Nothing, Cmd.none )


type Room
    = Room String


type Msg
    = ServerSentData D.Value
    | UserClickedCreateNewGame
    | UserClickedImAnAdmin
    | UserClickedImInTheWrongGame
    | GotCodeGiverMsg CodeGiver.AdminMsg
    | GotGameMsg Game.Msg
    | JoinedDifferentRoom Room
    | NOOP


update msg model =
    case msg of
        NOOP ->
            ( model, Cmd.none )

        JoinedDifferentRoom room ->
            ( ChoosingHowToStartGame <| Just room, Cmd.none )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    ( ChoosingHowToStartGame Nothing, joinLobby <| E.string "joindatlobby" )

        UserClickedImAnAdmin ->
            case model of
                InGame room gameModel ->
                    ( InCodeGiver room { cards = gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ServerSentData x ->
            -- TODO: this msg handlening should be consolidated
            let
                ( gameModel, cmd ) =
                    Game.decodeCardsFromServer Game.initModel x
            in
            ( InGame (Room "FAKE") gameModel, Cmd.map (always NOOP) cmd )

        UserClickedCreateNewGame ->
            ( ChoosingHowToStartGame Nothing, toSocket <| E.string "elmSaysCreateNewRoom" )

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


toolbarView model =
    div []
        [ button [ onClick UserClickedImAnAdmin ] [ text "uhm im actually a codegiver" ]
        , button [ onClick UserClickedImInTheWrongGame ] [ text "uhm im in the wrong game" ]
        , span [] [ text "room name goes here" ]
        ]


bodyView model =
    case model of
        ChoosingHowToStartGame maybeRoom ->
            div [ class "home-container" ]
                [ div [ class "centered-prompt" ]
                    [ div [ class "join" ]
                        [ h1 [] [ text "Game Code" ]
                        , input [] []
                        , button [ class "join-button" ] [ text "join" ]
                        ]
                    , div [ class "create" ]
                        [ button [ onClick UserClickedCreateNewGame ] [ text "CREATE NEW GAME" ]
                        ]
                    ]
                ]

        InCodeGiver _ codeGiverModel ->
            Html.map GotCodeGiverMsg <| CodeGiver.view codeGiverModel

        InGame _ gameModel ->
            Html.map GotGameMsg <| Game.view gameModel


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Codenames getting ready"
                , body = [ view m ]
                }
        , subscriptions = subscriptions
        }


socketHandler : Model -> D.Value -> Msg
socketHandler model rawCards =
    case model of
        InCodeGiver _ _ ->
            GotCodeGiverMsg (CodeGiver.Hey rawCards)

        InGame _ _ ->
            GotGameMsg (Game.ReceivedCardsFromServer rawCards)

        ChoosingHowToStartGame _ ->
            ServerSentData rawCards


roomDecoding raw =
    case D.decodeValue (D.map Room (D.field "room" D.string)) raw of
        Ok val ->
            JoinedDifferentRoom val

        Err _ ->
            JoinedDifferentRoom <| Room "ERROR"


subscriptions model =
    let
        sockets =
            [ fromSocket (socketHandler model)
            , joinedDifferentRoom roomDecoding
            ]
    in
    case model of
        ChoosingHowToStartGame _ ->
            Sub.batch sockets

        InGame _ gameModel ->
            Sub.batch <|
                sockets
                    ++ [ Sub.map GotGameMsg (Game.subscriptions gameModel)
                       ]

        _ ->
            Sub.batch sockets
