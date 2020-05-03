module CodeGiver exposing (..)

import Browser
import Game exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Socket exposing (..)



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : List GameCard
    }


initialCodeGiverModel =
    { cards = []
    }


init : () -> ( Model, Cmd AdminMsg )
init _ =
    ( initialCodeGiverModel
    , Cmd.none
    )



-- ---------------------------
-- UPDATE
-- ---------------------------


type AdminMsg
    = Clicked Hash
    | Hey Decode.Value
    | TriggerRestart


update : AdminMsg -> Model -> ( Model, Cmd AdminMsg )
update message model =
    case message of
        TriggerRestart ->
            ( model, restartGameSameRoom <| Encode.string "restart" )

        Clicked hash ->
            ( model
            , alsoToSocket (encodeHash hash)
            )

        Hey x ->
            codeGiverDecodeCardsFromServer model x



-- TODO: eesh


codeGiverDecodeCardsFromServer model x =
    case Decode.decodeValue cardsDecoder x of
        Ok decoded_thing ->
            ( { model | cards = decoded_thing }, Cmd.none )

        Err e ->
            ( model, Cmd.none )


turnOverCard turningOverTeam card =
    case card of
        GameCard UnTurned word originallyColored hash ->
            GameCard (Turned (TurnedOverBy turningOverTeam)) word originallyColored hash

        x ->
            x


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
    , alsoToSocket (encodeHash clickedHash)
    )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html AdminMsg
view model =
    div [ class "page-container" ]
        [ div [ class "board-container" ]
            [ div [ class "cards noselect" ] <| List.map cardView model.cards
            ]
        ]


adminBarView model =
    div [ onClick TriggerRestart ] [ text "new game" ]


cardView : GameCard -> Html AdminMsg
cardView card =
    case card of
        GameCard UnTurned (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card card-inner admin-unturned admin-" ++ teamToString team
                ]
                [ span [ class "word" ] [ text word ] ]

        GameCard (Turned (TurnedOverBy turnedOverByTeam)) (Word word) (OriginallyColored originallyColoredTeam) _ ->
            div
                [ class <| "card card-inner admin-turned admin-" ++ teamToString originallyColoredTeam ]
                [ span [ class "word" ] [ text word ] ]



-- ---------------------------
-- MAIN
-- ---------------------------


main : Program () Model AdminMsg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "ADMIN"
                , body = [ view m ]
                }
        , subscriptions = always Sub.none
        }
