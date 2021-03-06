module Main exposing (..)

import Animator
import Browser
import Browser.Dom as Dom
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


type Model
    = ChoosingHowToStartGame (Maybe Room) RoomTypings
    | InGame Room Game.Model


init _ =
    ( ChoosingHowToStartGame Nothing "", Cmd.none )


type Room
    = Room String


type Msg
    = UserClickedCreateNewGame
    | UserClickedImInTheWrongGame
    | GotGameMsg Game.Msg
    | JoinedARoom Room
    | UserTypedRoomToEnter String
    | UserClickedJoinGame
    | NOOP


flip f y x =
    f x y


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

        JoinedARoom room ->
            case model of
                ChoosingHowToStartGame _ _ ->
                    let
                        (Room roomie) =
                            room

                        ( gameModel, gameCmd ) =
                            Game.init roomie
                    in
                    ( InGame room gameModel
                    , Cmd.batch
                        [ Cmd.map GotGameMsg gameCmd
                        , Socket.elmSaysStartCardGame
                        ]
                    )

                _ ->
                    ( model, Cmd.none )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    ( ChoosingHowToStartGame Nothing "", Socket.joinLobby <| E.string "joindatlobby" )

        UserClickedJoinGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings ->
                    ( ChoosingHowToStartGame Nothing roomTypings, Socket.elmSaysJoinExistingRoom roomTypings )

                _ ->
                    ( model, Cmd.none )

        UserClickedCreateNewGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings ->
                    ( ChoosingHowToStartGame Nothing roomTypings
                    , Socket.elmSaysCreateNewRoom
                    )

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

        InGame _ gameModel ->
            Html.map GotGameMsg <| Game.view gameModel


toolbarView : Model -> Html Msg
toolbarView model =
    let
        f x =
            span [ class "in-room" ] [ text x ]
    in
    case model of
        InGame (Room room) _ ->
            f room

        _ ->
            text ""


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
                                InGame _ _ ->
                                    GotGameMsg (Game.ReceivedCardsFromServer rawValue)

                                ChoosingHowToStartGame _ _ ->
                                    NOOP

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
