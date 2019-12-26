module Admin exposing (..)

import Browser
import Card exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Main exposing (Model, fromSocket, toSocket)



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : List Card
    }


init : Int -> ( Model, Cmd AdminMsg )
init flags =
    ( { cards = []
      }
    , toSocket <| Encode.string "connect"
    )



-- ---------------------------
-- UPDATE
-- ---------------------------


type AdminMsg
    = Clicked Hash
    | Hey Decode.Value


update : AdminMsg -> Model -> ( Model, Cmd AdminMsg )
update message model =
    case message of
        Clicked hash ->
            handleClickUpdate hash model

        Hey x ->
            case Decode.decodeValue cardsDecoder x of
                Ok decoded_thing ->
                    let
                        updatedCards =
                            if model.cards == [] then
                                decoded_thing

                            else
                                transferOverStyles model.cards decoded_thing
                    in
                    ( { model | cards = updatedCards }, Cmd.none )

                Err e ->
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
    ( { model | cards = updatedCards }
    , toSocket (encodeHash clickedHash)
    )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html AdminMsg
view model =
    div [ class "page-container" ]
        [ div [ class "board-container" ]
            [ div [ class "cards" ] <| List.map cardView model.cards
            ]
        ]


cardView : Card -> Html AdminMsg
cardView card =
    case card of
        UnTurned _ (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card card-inner admin-unturned admin-" ++ teamToString team
                , onClick <| Clicked hash
                ]
                [ span [ class "word" ] [ text word ] ]

        Turned _ (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) _ ->
            div [ class "card admin-turned" ] []



-- ---------------------------
-- MAIN
-- ---------------------------


main : Program Int Model AdminMsg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "ADMIN"
                , body = [ view m ]
                }
        , subscriptions = \_ -> fromSocket Hey
        }
