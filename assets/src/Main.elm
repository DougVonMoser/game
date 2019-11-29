module Main exposing (main)

import Browser
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font
import Html exposing (Html)
import Http exposing (Error(..))
import Json.Decode as Decode
import Websocket exposing (Event(..))



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { counter : Int
    , serverMessage : String
    , socketInfo : SocketStatus
    , cards : List Card
    }


type SocketStatus
    = Unopened
    | Connected Websocket.ConnectionInfo
    | Closed Int



-- Card should be monoidal for the comprehensive game
-- who flipped, originalColor, unique Identifier yada yada


type Card
    = UnTurned Word OriginallyColored Hash
    | Turned Word TurnedOverBy OriginallyColored Hash



--unique identifier


type Hash
    = Hash Int


type OriginallyColored
    = OriginallyColored Team


type TurnedOverBy
    = TurnedOverBy Team


type Word
    = Word String


type Team
    = Red
    | Blue


init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags
      , serverMessage = "nothing clicked yet"
      , socketInfo = Unopened
      , cards = initialCards
      }
    , Cmd.none
    )


initialCards =
    List.repeat 25 ()
        |> List.indexedMap
            (\x _ ->
                UnTurned (Word "testing") (OriginallyColored Blue) (Hash x)
            )



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Clicked Hash


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Clicked hash ->
            handleClickUpdate hash model


handleClickUpdate clickedHash model =
    let
        updatedCards =
            List.map
                (\card ->
                    if cardMatchesHash card clickedHash then
                        turnOverCard Red card

                    else
                        card
                )
                model.cards
    in
    ( { model | cards = updatedCards, serverMessage = "something got clicked" }, Cmd.none )


turnOverCard turningOverTeam card =
    case card of
        UnTurned word originallyColored hash ->
            Turned word (TurnedOverBy turningOverTeam) originallyColored hash

        Turned _ _ _ _ ->
            Debug.todo "OH MY GOD"


cardMatchesHash : Card -> Hash -> Bool
cardMatchesHash card (Hash hash) =
    case card of
        UnTurned _ _ (Hash hash2) ->
            hash == hash2

        Turned _ _ _ (Hash hash2) ->
            hash == hash2



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    Element.layout [] <|
        column [ width (px 1000), spacing 80, centerX, centerY ] <|
            [ el [] (text model.serverMessage)
            , cardsView model.cards
            ]


cardsView cards =
    wrappedRow [ spacing 80 ] <| List.map cardView cards


cardView : Card -> Element Msg
cardView card =
    case card of
        UnTurned (Word word) (OriginallyColored team) hash ->
            el
                [ Background.color (rgb255 90 90 90)
                , Font.color (rgb255 255 255 255)
                , Border.rounded 3
                , width (px 120)
                , height (px 80)
                , padding 30
                , onClick <| Clicked hash
                , pointer
                ]
                (text word)

        Turned (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) _ ->
            el
                [ Background.color <| getTeamColor originallyColoredTeam
                , Border.rounded 3
                , width (px 120)
                , height (px 80)
                , padding 30
                ]
                none


getTeamColor team =
    case team of
        Red ->
            rgb255 255 0 0

        Blue ->
            rgb255 0 0 255



-- ---------------------------
-- MAIN
-- ---------------------------


main : Program Int Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Codenames!"
                , body = [ view m ]
                }
        , subscriptions = \_ -> Sub.none
        }
