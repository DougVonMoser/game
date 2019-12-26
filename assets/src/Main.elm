port module Main exposing (..)

import Animation as A exposing (px)
import Browser
import Card exposing (..)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
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


port fromSocket : (Decode.Value -> msg) -> Sub msg



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Clicked Hash
    | Hey Decode.Value


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Clicked hash ->
            handleClickUpdate hash model

        Hey x ->
            case Decode.decodeValue cardsDecoder x of
                Ok decoded_thing ->
                    ( { model | cards = decoded_thing }, Cmd.none )

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
    ( { model | cards = updatedCards, serverMessage = "something got clicked" }
    , toSocket (encodeHash clickedHash)
    )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ div [ class "score-container" ] <| scoreView model.cards
        , div [ class "board-container" ]
            [ div [ class "cards" ] <| List.map cardView model.cards
            ]
        ]


scoreView : List Card -> List (Html Msg)
scoreView cards =
    [ teamScoreView cards Red
    , teamScoreView cards Blue
    ]


teamScoreView : List Card -> Team -> Html Msg
teamScoreView cards team =
    div [ class "team-score" ]
        [ h1 [ class "team" ] [ text <| teamToString team ]
        , span [ class "score" ] [ text <| String.fromInt <| unTurnedCountOfTeam cards team ]
        ]


unTurnedCountOfTeam : List Card -> Team -> Int
unTurnedCountOfTeam cards team =
    List.filter (\c -> isUnTurned c && cardBelongsToTeam c team) cards
        |> List.length


cardView : Card -> Html Msg
cardView card =
    case card of
        UnTurned (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card "
                ]
                [ div [ class "card-inner" ]
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class "card-back " ] []
                    ]
                ]

        Turned (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) _ ->
            div
                [ class <| "card"
                ]
                [ div [ class "card-inner turnt" ]
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class <| "card-back audience-" ++ teamToString originallyColoredTeam ] []
                    ]
                ]



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
