module Admin exposing (..)

import Browser
import Card exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Main exposing (Model, Msg(..), fromSocket, toSocket)



-- ---------------------------
-- MODEL
-- ---------------------------
-- ---------------------------
-- UPDATE
-- ---------------------------
-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ div [ class "board-container" ]
            [ div [ class "cards" ] <| List.map cardView model.cards
            ]
        ]


cardView : Card -> Html Msg
cardView card =
    case card of
        UnTurned (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card card-inner admin-unturned admin-" ++ teamToString team
                , onClick <| Main.Clicked hash
                ]
                [ span [ class "word" ] [ text word ] ]

        Turned (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) _ ->
            div [ class "card admin-turned" ] []



-- ---------------------------
-- MAIN
-- ---------------------------


main : Program Int Model Msg
main =
    Browser.document
        { init = Main.init
        , update = Main.update
        , view =
            \m ->
                { title = "ADMIN"
                , body = [ view m ]
                }
        , subscriptions = \_ -> fromSocket Main.Hey
        }
