port module Main exposing (..)

import Browser
import Browser.Dom as Dom
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


init _ =
    ( ChoosingHowToStartGame, Cmd.none )


type Msg
    = ServerSentData D.Value
    | UserClickedCreateNewGame
    | NOOP


update msg model =
    case msg of
        NOOP ->
            ( model, Cmd.none )

        ServerSentData x ->
            let
                ( gameModel, cmd ) =
                    Game.decodeCardsFromServer Game.initModel x
            in
            ( InGame gameModel, Cmd.map (always NOOP) cmd )

        UserClickedCreateNewGame ->
            ( ChoosingHowToStartGame, toSocket <| E.string "elmSaysCreateNewRoom" )


view model =
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

        InGame gameModel ->
            Html.map (always UserClickedCreateNewGame) <| Game.view gameModel


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


socketHandler : D.Value -> Msg
socketHandler rawCards =
    ServerSentData rawCards


subscriptions model =
    Sub.batch
        [ fromSocket socketHandler ]
