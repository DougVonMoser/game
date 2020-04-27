module Game exposing (..)

import Animation exposing (deg, px)
import Animation.Messenger exposing (State)
import Animator as A
import Animator.Inline
import Browser
import Browser.Dom as Dom
import Color
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import List.Extra as List
import Maybe.Extra as Maybe
import Socket exposing (..)
import Task



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : A.Timeline List GameCard
    }


initModel =
    { cards = []
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel
    , Cmd.none
    )


type GameCard
    = GameCard TurnedStatus Word OriginallyColored Hash


type TurnedStatus
    = UnTurned
    | Turned TurnedOverBy


type OriginallyColored
    = OriginallyColored Team


type TurnedOverBy
    = TurnedOverBy Team


type Word
    = Word String


type Team
    = Red
    | Blue
    | NoTeam



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = ReceivedCardsFromServer D.Value
    | Animate Animation.Msg
    | UserClickedOnHash Hash


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UserClickedOnHash hash ->
            ( model, alsoToSocket <| encodeHash hash )

        Animate animMsg ->
            ( model, Cmd.none )

        ReceivedCardsFromServer x ->
            decodeCardsFromServer model x


decodeCardsFromServer model x =
    case D.decodeValue cardsDecoder x of
        Ok decoded_cards ->
            case model.cards of
                [] ->
                    ( { model | cards = List.map A.init decoded_cards }, Cmd.none )

                existingCards ->
                    let
                        updated_cards =
                            updateCardsToLatest decoded_cards existingCards
                    in
                    ( { model | cards = updated_cards }, Cmd.none )

        Err e ->
            ( model, Cmd.none )


updateCardsToLatest : List GameCard -> List (A.Timeline GameCard) -> List (A.Timeline GameCard)
updateCardsToLatest x y =
    y



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ -- div [ class "score-container" ] <| scoreView model.cards,
          div [ class "outer-board" ]
            [ div [ id "board-container", class "board-container" ]
                [ div [ class "cards noselect" ] <| List.indexedMap cardView model.cards
                ]
            ]
        ]


wiggleWidIt =
    []
        |> List.map
            (\(SpecificWiggle dur transX transY rotDeg) ->
                Animation.toWith
                    (Animation.easing { duration = dur, ease = \x -> x })
                    [ Animation.translate transX transY, Animation.rotate rotDeg ]
            )


getTurnt =
    wiggleWidIt
        ++ [ Animation.to [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]
           ]


scoreView : List GameCard -> List (Html Msg)
scoreView cards =
    [ teamScoreView cards Red
    , teamScoreView cards Blue
    ]


teamScoreView : List GameCard -> Team -> Html Msg
teamScoreView cards team =
    div [ class "team-score" ]
        [ h1 [ class "team" ] [ text <| teamToString team ]
        , span [ class "score" ] [ text <| String.fromInt <| unTurnedCountOfTeam cards team ]
        ]


unTurnedCountOfTeam : List GameCard -> Team -> Int
unTurnedCountOfTeam cards team =
    List.filter (\c -> isUnTurned c && cardBelongsToTeam c team) cards
        |> List.length


cardView : Int -> A.Timeline GameCard -> Html Msg
cardView count card =
    case A.current card of
        GameCard _ (Word word) (OriginallyColored team) hash ->
            div
                [ class "card "
                , Animator.Inline.borderColor card <|
                    \state ->
                        if isUnTurned state then
                            Color.rgb255 255 96 96

                        else
                            Color.black
                , onClick <| UserClickedOnHash hash
                ]
                [ div [ class "card-inner", id <| hashToIdSelectorString hash ]
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class <| "card-back audience-" ++ teamToString team ] [ span [ class "word" ] [ text word ] ]
                    ]
                ]



-- ---------------------------
-- MAIN
-- ---------------------------


animator : A.Animator Model
animator =
    A.watching
        -- we tell the animator how
        -- to get the checked timeline using .checked
        (\model -> List.map)
        -- and we tell the animator how
        -- to update that timeline as well
        (\newChecked model ->
            { model | checked = newChecked }
        )
        A.animator



-- anThing : (List (A.Timeline GameCard) -> A.Timeline GameCard) -> (Timeline GameCard -> model -> model)
-- anHelper :


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , update = update
        , view =
            \m ->
                { title = "Codenames Scoreboard"
                , body = [ view m ]
                }
        , subscriptions = subscriptions
        }


subscriptions model =
    Sub.batch
        []



-- ---------------------------
-- DECODERS
-- ---------------------------


cardsDecoder =
    D.list cardDecoder


cardDecoder : D.Decoder GameCard
cardDecoder =
    at [ "turned_over_by" ] (D.nullable string)
        |> D.andThen
            (\maybeRedBlue ->
                case maybeRedBlue of
                    Just redBlueString ->
                        D.map4 funky4
                            (at [ "hash" ] string)
                            (at [ "turned_over_by" ] teamDecoder)
                            (at [ "original_color" ] teamDecoder)
                            (at [ "word" ] string)

                    Nothing ->
                        D.map3 funky
                            (at [ "hash" ] string)
                            (at [ "original_color" ] teamDecoder)
                            (at [ "word" ] string)
            )


funky : String -> Team -> String -> GameCard
funky hash original_color word =
    GameCard UnTurned
        (Word word)
        (OriginallyColored original_color)
        (Hash hash)


funky4 : String -> Team -> Team -> String -> GameCard
funky4 hash turnedOverBy original_color word =
    GameCard (Turned (TurnedOverBy turnedOverBy)) (Word word) (OriginallyColored original_color) (Hash hash)


unturnt =
    Animation.style [ Animation.translate (px 0) (px 0), Animation.rotate3d (deg 0) (deg 0) (deg 0) ]


defaultTurnt =
    Animation.style [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]


teamDecoder =
    D.string
        |> D.andThen
            (\color ->
                case color of
                    "red" ->
                        D.succeed Red

                    "blue" ->
                        D.succeed Blue

                    "gray" ->
                        D.succeed NoTeam

                    x ->
                        D.fail <| "unrecognized color of " ++ x
            )


type Hash
    = Hash String


hashToString (Hash x) =
    x


hashToIdSelectorString hash =
    "x" ++ hashToString hash


encodeHash (Hash x) =
    E.string x


hashesAreEqual (Hash hash1) (Hash hash2) =
    hash1 == hash2


isUnTurned : GameCard -> Bool
isUnTurned card =
    case card of
        GameCard UnTurned _ _ _ ->
            True

        _ ->
            False


type SpecificWiggle
    = SpecificWiggle Float Animation.Length Animation.Length Animation.Angle


cardBelongsToTeam : GameCard -> Team -> Bool
cardBelongsToTeam card team =
    case card of
        GameCard _ _ (OriginallyColored teamCheck) _ ->
            team == teamCheck


sameCard : GameCard -> GameCard -> Bool
sameCard c1 c2 =
    case c1 of
        GameCard _ _ _ hash ->
            cardMatchesHash c2 hash


cardMatchesHash : GameCard -> Hash -> Bool
cardMatchesHash card hash1 =
    case card of
        GameCard _ _ _ hash2 ->
            hashesAreEqual hash1 hash2


teamToString team =
    case team of
        Red ->
            "red"

        Blue ->
            "blue"

        NoTeam ->
            "gray"
