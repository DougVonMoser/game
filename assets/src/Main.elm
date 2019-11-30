port module Main exposing (..)

import Browser
import Card exposing (..)
import Element exposing (..)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
import Element.Font as Font
import Html exposing (Html)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { counter : Int
    , serverMessage : String
    , cards : List Card
    }


init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags
      , serverMessage = "nothing clicked yet"
      , cards = initialCards
      }
    , toSocket <| Encode.string "connect"
    )


port toSocket : Encode.Value -> Cmd msg


port fromSocket : (String -> msg) -> Sub msg



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Clicked Hash
    | Hey String


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Clicked hash ->
            handleClickUpdate hash model

        Hey _ ->
            ( model, Cmd.none )


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



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    Element.layout [] <|
        column [ width (px 1000), spacing 80, centerX, centerY ] <|
            [ cardsView model.cards ]


cardsView : List Card -> Element Msg
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
                { title = "Codenames Scoreboard"
                , body = [ view m ]
                }
        , subscriptions = \_ -> fromSocket Hey
        }
