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


type Model
    = ChoosingHowToStartGame (Maybe Room) String
    | InLobby Room (List Player)
    | InGame Room Game.Model
    | InCodeGiver Room CodeGiver.Model


init _ =
    ( ChoosingHowToStartGame Nothing "", Cmd.none )


type Room
    = Room String


type Msg
    = ServerSentData D.Value
      --| ServerSentLatestCards
    | UserClickedCreateNewGame
    | UserClickedImNotAnAdmin
    | UserClickedImAnAdmin
    | UserClickedImInTheWrongGame
    | GotCodeGiverMsg CodeGiver.AdminMsg
    | GotGameMsg Game.Msg
    | JoinedDifferentRoom Room
    | UserTypedRoomToEnter String
    | UserClickedJoinGame
    | NOOP


type Player
    = Player String PlayerHash


flip f y x =
    f x y


playerDecoder : ( String, String ) -> Player
playerDecoder ( id, name ) =
    Player name (PlayerHash id)


playersDecoder =
    D.keyValuePairs (D.field "name" D.string)
        |> D.map (List.map playerDecoder)


presenceStateDecoder =
    D.field "value" playersDecoder


type PlayerHash
    = PlayerHash String


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
                    ( ChoosingHowToStartGame Nothing "", Socket.joinLobby <| E.string "joindatlobby" )

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

        --        ServerSentData x ->
        --            case model of
        --                ChoosingHowToStartGame (Just room) _ ->
        --                    let
        --                        ( gameModel, cmd ) =
        --                            Game.decodeCardsFromServer Game.initModel x
        --                    in
        --                    ( InLobby room gameModel, Cmd.map (always NOOP) cmd )
        --
        --                _ ->
        --                    ( model, Cmd.none )
        ServerSentData x ->
            case model of
                ChoosingHowToStartGame (Just room) _ ->
                    ( InLobby room [], Cmd.none )

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
            ( ChoosingHowToStartGame Nothing ""
            , Socket.toSocket <|
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


toolbarView : Model -> Html Msg
toolbarView model =
    case model of
        ChoosingHowToStartGame _ _ ->
            text ""

        InLobby (Room room) playerSet ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImAnAdmin ] [ text "I'm giving clues this round!" ]
                , button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        InGame (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImAnAdmin ] [ text "I'm giving clues this round!" ]
                , button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]

        InCodeGiver (Room room) _ ->
            div [ class "toolbar" ]
                [ button [ onClick UserClickedImNotAnAdmin ] [ text "I aint giving clues this round!" ]
                , button [ onClick UserClickedImInTheWrongGame ] [ text "Back to home screen" ]
                , span [] [ text <| "in room " ++ room ]
                ]


bodyView : Model -> Html Msg
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

        InLobby room playerSet ->
            h1 [] [ text " WELCOME TO THE LOBBY " ]

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
                ( " disabled", "Enter 4-Letter Room Code" )

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

                                ChoosingHowToStartGame _ _ ->
                                    ServerSentData rawValue

                                InLobby _ _ ->
                                    ServerSentData rawValue

                        Err _ ->
                            NOOP

                "presence_state" ->
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

