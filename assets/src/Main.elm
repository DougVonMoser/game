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


port fromSocket : (D.Value -> msg) -> Sub msg


type Model
    = ChoosingHowToStartGame
    | InGame Game.Model
    | InCodeGiver CodeGiver.Model


init _ =
    ( ChoosingHowToStartGame, Cmd.none )


type Msg
    = ServerSentData D.Value
    | UserClickedCreateNewGame
    | UserClickedImAnAdmin
    | UserClickedImInTheWrongGame
    | GotCodeGiverMsg CodeGiver.AdminMsg
    | GotGameMsg Game.Msg
    | NOOP


update msg model =
    case msg of
        NOOP ->
            ( model, Cmd.none )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    -- NEED TO JOIN ROOM:LOBBY HERE
                    ( ChoosingHowToStartGame, Cmd.none )

        UserClickedImAnAdmin ->
            case model of
                InGame gameModel ->
                    ( InCodeGiver { cards = gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ServerSentData x ->
            let
                ( gameModel, cmd ) =
                    Game.decodeCardsFromServer Game.initModel x
            in
            ( InGame gameModel, Cmd.map (always NOOP) cmd )

        UserClickedCreateNewGame ->
            ( ChoosingHowToStartGame, toSocket <| E.string "elmSaysCreateNewRoom" )

        GotCodeGiverMsg msgCG ->
            case model of
                InCodeGiver modelCG ->
                    let
                        ( newModelCG, newCmdCG ) =
                            CodeGiver.update msgCG modelCG
                    in
                    ( InCodeGiver newModelCG, Cmd.map GotCodeGiverMsg newCmdCG )

                _ ->
                    ( model, Cmd.none )

        GotGameMsg msgGAME ->
            case model of
                InGame modelGAME ->
                    let
                        ( newModelGAME, newCmdGAME ) =
                            Game.update msgGAME modelGAME
                    in
                    ( InGame newModelGAME, Cmd.map GotGameMsg newCmdGAME )

                _ ->
                    ( model, Cmd.none )


view model =
    div []
        [ toolbarView model
        , bodyView model
        ]


toolbarView model =
    div []
        [ button [ onClick UserClickedImAnAdmin ] [ text "im actually an admin" ]
        , button [ onClick UserClickedImInTheWrongGame ] [ text "im in the wrong game" ]
        ]


bodyView model =
    case model of
        ChoosingHowToStartGame ->
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

        InCodeGiver codeGiverModel ->
            Html.map GotCodeGiverMsg <| CodeGiver.view codeGiverModel

        InGame gameModel ->
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
        InCodeGiver _ ->
            GotCodeGiverMsg (CodeGiver.Hey rawCards)

        InGame _ ->
            GotGameMsg (Game.ReceivedCardsFromServer rawCards)

        ChoosingHowToStartGame ->
            ServerSentData rawCards


subscriptions model =
    case model of
        ChoosingHowToStartGame ->
            fromSocket (socketHandler model)

        InGame gameModel ->
            Sub.batch
                [ fromSocket (socketHandler model)
                , Sub.map GotGameMsg (Game.subscriptions gameModel)
                ]

        _ ->
            fromSocket (socketHandler model)
