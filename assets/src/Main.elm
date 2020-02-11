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
import Socket exposing (..)


type Model
    = ChoosingHowToStartGame (Maybe Room) String
    | InGame Room Game.Model
    | InCodeGiver Room CodeGiver.Model


init _ =
    ( ChoosingHowToStartGame Nothing "", Cmd.none )


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
    | UserTypedRoomToEnter String
    | UserClickedJoinGame
    | NOOP


update msg model =
    case msg of
        NOOP ->
            ( model, Cmd.none )

        UserTypedRoomToEnter s ->
            case model of
                ChoosingHowToStartGame maybeRoom roomTypings ->
                    ( ChoosingHowToStartGame maybeRoom <| String.toUpper s, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        JoinedDifferentRoom room ->
            ( ChoosingHowToStartGame (Just room) "", Cmd.none )

        UserClickedImInTheWrongGame ->
            case model of
                _ ->
                    ( ChoosingHowToStartGame Nothing "", joinLobby <| E.string "joindatlobby" )

        UserClickedImAnAdmin ->
            case model of
                InGame room gameModel ->
                    ( InCodeGiver room { cards = gameModel.cards }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ServerSentData x ->
            case model of
                ChoosingHowToStartGame (Just room) _ ->
                    let
                        ( gameModel, cmd ) =
                            Game.decodeCardsFromServer Game.initModel x
                    in
                    ( InGame room gameModel, Cmd.map (always NOOP) cmd )

                _ ->
                    ( model, Cmd.none )

        UserClickedJoinGame ->
            case model of
                ChoosingHowToStartGame Nothing roomTypings ->
                    ( ChoosingHowToStartGame Nothing roomTypings
                    , toSocket <|
                        E.object
                            [ ( "action", E.string "elmSaysJoinExistingRoom" )
                            , ( "room", E.string roomTypings )
                            ]
                    )

                _ ->
                    ( model, Cmd.none )

        UserClickedCreateNewGame ->
            ( ChoosingHowToStartGame Nothing ""
            , toSocket <|
                E.object
                    [ ( "action", E.string "elmSaysCreateNewRoom" )
                    ]
            )

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
    let
        listOfButtons =
            case model of
                ChoosingHowToStartGame _ _ ->
                    []

                InGame (Room room) _ ->
                    [ button [ onClick UserClickedImAnAdmin ] [ text "I'm giving clues this round!" ]
                    , button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                    , span [] [ text <| "in room " ++ room ]
                    ]

                InCodeGiver (Room room) _ ->
                    [ button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                    , span [] [ text <| "in room " ++ room ]
                    ]
    in
    div [] listOfButtons


bodyView model =
    case model of
        ChoosingHowToStartGame maybeRoom roomTypings ->
            div [ class "home-container" ]
                [ div [ class "join" ]
                    [ h1 [] [ text "Game Code" ]
                    , input [ onInput UserTypedRoomToEnter, maxlength 4, value roomTypings ] []
                    , joinButton roomTypings
                    ]
                , div [ class "create" ]
                    [ button [ onClick UserClickedCreateNewGame ] [ text "CREATE NEW GAME" ]
                    ]
                , div [ class "gif" ] [ img [ src "https://s3.amazonaws.com/dougvonmoser.com/commonplace.gif" ] [] ]
                ]

        InCodeGiver _ codeGiverModel ->
            Html.map GotCodeGiverMsg <| CodeGiver.view codeGiverModel

        InGame _ gameModel ->
            Html.map GotGameMsg <| Game.view gameModel


joinButton roomTypings =
    let
        isDisabled =
            String.length roomTypings /= 4

        ( disabledClass, disabledText ) =
            if isDisabled then
                ( " disabled", "Enter 4-Letter Code" )

            else
                ( "", "Play!" )
    in
    button [ onClick UserClickedJoinGame, class ("join-button" ++ disabledClass), disabled isDisabled ] [ text disabledText ]


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

        ChoosingHowToStartGame _ _ ->
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
        ChoosingHowToStartGame _ _ ->
            Sub.batch sockets

        InGame _ gameModel ->
            Sub.batch <|
                sockets
                    ++ [ Sub.map GotGameMsg (Game.subscriptions gameModel)
                       ]

        _ ->
            Sub.batch sockets
