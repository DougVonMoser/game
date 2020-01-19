port module CodeGiver exposing (..)

import Browser
import Game exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)


port alsoToSocket : Encode.Value -> Cmd msg



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : List Card
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
            --( model, toSocket <| Encode.string "restart" )
            --( model, alsoToSocket <| Encode.string "restart" )
            ( model, Cmd.none )

        Clicked hash ->
            handleClickUpdate hash model

        Hey x ->
            codeGiverDecodeCardsFromServer model x


codeGiverDecodeCardsFromServer model x =
    case Decode.decodeValue cardsDecoder x of
        Ok decoded_thing ->
            let
                ( updatedCards, _ ) =
                    if model.cards == [] then
                        ( decoded_thing, Nothing )

                    else
                        transferOverStyles model.cards decoded_thing
            in
            ( { model | cards = updatedCards }, Cmd.none )

        Err e ->
            ( model, Cmd.none )


turnOverCard turningOverTeam card =
    case card of
        UnTurned style word originallyColored hash ->
            Turned style word (TurnedOverBy turningOverTeam) originallyColored hash

        (Turned _ _ _ _ _) as x ->
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
      --, toSocket (encodeHash clickedHash)
    , alsoToSocket (encodeHash clickedHash)
    )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html AdminMsg
view model =
    div [ class "admin-container" ]
        [ div [ class "admin-bar" ] [ adminBarView model ]
        , div [ class "board-container" ]
            [ div [ class "admin-cards" ] <| List.map cardView model.cards
            ]
        ]


adminBarView model =
    div [ onClick TriggerRestart ] [ text "new game" ]


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
