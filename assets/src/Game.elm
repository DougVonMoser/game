module Game exposing (..)

import Animation exposing (deg, px)
import Animation.Messenger exposing (State)
import Animator as A
import Animator.Css
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
import Time



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : List (A.Timeline GameCard)
    , gameStatus : GameStatus
    }


type GameStatus
    = Playing
    | ATeamWon Team


initModel =
    { cards = []
    , gameStatus = Playing
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel
    , Cmd.none
    )


type alias GameCard =
    { turnedStatus : TurnedStatus
    , word : Word
    , originallyColored : OriginallyColored
    , hash : Hash
    }


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
    | Tick Time.Posix
    | UserClickedRestartGame


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UserClickedOnHash hash ->
            ( model, alsoToSocket <| encodeHash hash )

        Animate animMsg ->
            ( model, Cmd.none )

        ReceivedCardsFromServer x ->
            ( decodeCardsFromServer model x, Cmd.none )

        UserClickedRestartGame ->
            ( model, restartGameSameRoom <| E.string "" )

        Tick newTime ->
            ( A.update newTime (animator model) model
            , Cmd.none
            )


decodeCardsFromServer model x =
    Result.map (doTheThing model) (D.decodeValue cardsDecoder x)
        |> Result.withDefault model


doTheThing : Model -> List GameCard -> Model
doTheThing model decoded_cards =
    case ( model.cards, model.gameStatus ) of
        -- dont have cards yet
        ( [], _ ) ->
            let
                updated_cards =
                    List.map A.init decoded_cards

                updated_status =
                    updateStatusFromCards decoded_cards
            in
            { model | cards = updated_cards, gameStatus = updated_status }

        -- someone won, but how does a non clickie new game get gamestatus
        -- haha wo lines below me
        -- reset
        ( _, ATeamWon _ ) ->
            { model | cards = List.map A.init decoded_cards, gameStatus = Playing }

        -- new card played and someone might win
        ( existingCards, Playing ) ->
            let
                updated_cards =
                    updateCardsToLatest decoded_cards existingCards

                updated_status =
                    updateStatusFromCards decoded_cards
            in
            { model | cards = updated_cards, gameStatus = updated_status }


updateStatusFromCards : List GameCard -> GameStatus
updateStatusFromCards cards =
    if List.filter isRedCard cards |> List.all isTurned then
        ATeamWon Red

    else if List.filter isBlueCard cards |> List.all isTurned then
        ATeamWon Blue

    else
        Playing


isTurned : GameCard -> Bool
isTurned card =
    case card.turnedStatus of
        Turned _ ->
            True

        UnTurned ->
            False


isBlueCard : GameCard -> Bool
isBlueCard { originallyColored } =
    case originallyColored of
        OriginallyColored x ->
            x == Blue


isRedCard : GameCard -> Bool
isRedCard { originallyColored } =
    case originallyColored of
        OriginallyColored x ->
            x == Red


updateCardsToLatest : List GameCard -> List (A.Timeline GameCard) -> List (A.Timeline GameCard)
updateCardsToLatest freshFromServerCards existingCards =
    List.map
        (\existingCard ->
            let
                --existingCurrentCard
                eCC =
                    A.current existingCard

                existingTurnedStatus =
                    eCC.turnedStatus

                existingHash =
                    eCC.hash
            in
            case findCardByHash existingHash freshFromServerCards of
                Just newCard ->
                    case existingTurnedStatus /= newCard.turnedStatus of
                        True ->
                            A.go A.immediately newCard existingCard

                        False ->
                            existingCard

                Nothing ->
                    Debug.todo "SHITTTTT"
         --existingCard
        )
        existingCards



--- ---------------------------
--- VIEW
--- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ div [ id "board-container", class "board-container" ]
            [ div [ class "cards noselect" ] <| List.indexedMap cardView model.cards
            , gameFinishedPrompt model
            ]
        ]


gameFinishedPrompt model =
    case model.gameStatus of
        Playing ->
            text ""

        ATeamWon team ->
            div [ class <| "finished-prompt " ++ teamToString team ]
                [ h1 [ class "team-won" ] [ text <| "yay " ++ teamToString team ++ " team won" ]
                , img [ class "win-gif", src "https://media.giphy.com/media/aZXRIHxo9saPe/giphy.gif" ] []
                , button [ class "restart-game", onClick UserClickedRestartGame ] [ text "PLAY AGAIN" ]
                ]


flip f y x =
    f x y


findCardByHash : Hash -> List GameCard -> Maybe GameCard
findCardByHash hash oldies =
    List.find (flip cardMatchesHash hash) oldies


getTurnt =
    [ Animation.to [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]
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
cardView count timelineCard =
    let
        currentCard =
            A.current timelineCard

        (Word word) =
            currentCard.word

        (OriginallyColored team) =
            currentCard.originallyColored

        hash =
            currentCard.hash
    in
    div
        [ class "card "
        , Animator.Inline.backgroundColor timelineCard <|
            \state ->
                if isUnTurned state then
                    Color.rgb255 230 233 237

                else
                    teamToColor team
        , onClick <| UserClickedOnHash hash
        ]
        [ span
            [ class "word"
            , Animator.Inline.textColor timelineCard <|
                \state ->
                    if isUnTurned state then
                        Color.black

                    else
                        Color.white
            ]
            [ text word ]
        ]



--Animation.style [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]
-- ---------------------------
-- MAIN
-- ---------------------------


animator : Model -> A.Animator Model
animator model =
    thing model


folder : A.Timeline GameCard -> A.Animator Model -> A.Animator Model
folder x y =
    A.watching
        (\model -> findTimelineGameCard model.cards x)
        updateThatTimeline
        y


updateThatTimeline : A.Timeline GameCard -> Model -> Model
updateThatTimeline updatedCard model =
    let
        f old =
            if sameCard (A.current old) (A.current updatedCard) then
                updatedCard

            else
                old

        updated_cards =
            List.map f model.cards
    in
    { model | cards = updated_cards }


findTimelineGameCard : List (A.Timeline GameCard) -> A.Timeline GameCard -> A.Timeline GameCard
findTimelineGameCard listy x =
    case List.find ((==) x) listy of
        Just zz ->
            zz

        Nothing ->
            Debug.todo "SHFUCK"


thing model =
    List.foldl folder A.animator model.cards



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
    -- (4) - turning out Animator into a subscription
    -- this is where the animator will decide to have a subscription to AnimationFrame or not.
    A.toSubscription Tick model (animator model)



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
    card.turnedStatus == UnTurned


type SpecificWiggle
    = SpecificWiggle Float Animation.Length Animation.Length Animation.Angle


cardBelongsToTeam : GameCard -> Team -> Bool
cardBelongsToTeam card team =
    case card.originallyColored of
        OriginallyColored teamCheck ->
            team == teamCheck


sameCard : GameCard -> GameCard -> Bool
sameCard c1 c2 =
    cardMatchesHash c2 c1.hash


cardMatchesHash : GameCard -> Hash -> Bool
cardMatchesHash card hash1 =
    hashesAreEqual hash1 card.hash


teamToString team =
    case team of
        Red ->
            "red"

        Blue ->
            "blue"

        NoTeam ->
            "gray"


teamToColor team =
    case team of
        Red ->
            Color.rgb255 209 103 99

        Blue ->
            Color.rgb255 85 151 207

        NoTeam ->
            Color.rgb255 189 187 186
