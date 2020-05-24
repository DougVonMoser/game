module Game exposing (..)

import Animator as A
import Animator.Css
import Animator.Inline
import Browser
import Browser.Dom
import Browser.Events
import Color
import Firework
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import List.Extra as List
import Maybe.Extra as Maybe
import Particle exposing (Particle)
import Particle.System as System exposing (System)
import Socket exposing (..)
import Task
import Time



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { cards : List (A.Timeline GameCard)
    , gameStatus : GameStatus
    , window : Window
    , firework : System Firework.Firework
    }


type GameStatus
    = WaitingOnCardsFromServer
    | Playing AudienceOrCodeGiver
    | ATeamWon Team


type AudienceOrCodeGiver
    = Audience
    | CodeGiver


initModel =
    { cards = []
    , gameStatus = WaitingOnCardsFromServer
    , window = { width = 800, height = 500 }
    , firework = Firework.fireworkInit
    }


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel
    , Browser.Dom.getViewport
        |> Task.attempt
            (\viewportResult ->
                case viewportResult of
                    Ok viewport ->
                        WindowSize
                            (round viewport.scene.width)
                            (round viewport.scene.height)

                    Err err ->
                        WindowSize
                            (round 800)
                            (round 600)
            )
    )


type alias GameCard =
    { turnedStatus : TurnedStatus
    , word : Word
    , originallyColored : Team
    , hash : Hash
    }


type TurnedStatus
    = UnTurned
    | Turned TurnedOverBy


type alias TurnedOverBy =
    Team


type alias Word =
    String


type Team
    = Red
    | Blue
    | NoTeam



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = ReceivedCardsFromServer D.Value
    | UserClickedOnHash Hash
    | Tick Time.Posix
    | UserClickedRestartGame
    | UserClickedSwitchToAudience
    | UserClickedSwitchToCodegiver
    | WindowSize Int Int
    | ParticleMsg (System.Msg Firework.Firework)
    | Detonate Team


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UserClickedOnHash hash ->
            ( model, alsoToSocket <| encodeHash hash )

        UserClickedSwitchToCodegiver ->
            ( { model | gameStatus = Playing CodeGiver }, Cmd.none )

        UserClickedSwitchToAudience ->
            ( { model | gameStatus = Playing Audience }, Cmd.none )

        UserClickedRestartGame ->
            ( model, restartGameSameRoom <| E.string "" )

        Tick newTime ->
            ( A.update newTime (animator model) model
            , Cmd.none
            )

        WindowSize width height ->
            ( { model
                | window =
                    { width = width
                    , height = height
                    }
              }
            , Cmd.none
            )

        ReceivedCardsFromServer x ->
            ( handleReceivedCardDValue x model, Cmd.none )

        ParticleMsg inner ->
            ( { model | firework = System.update inner model.firework }, Cmd.none )

        Detonate team ->
            let
                color =
                    case team of
                        Red ->
                            Firework.Red

                        Blue ->
                            Firework.Blue

                        NoTeam ->
                            Firework.Green
            in
            ( { model
                | firework =
                    Firework.fireworkUpdate model.firework color
              }
            , Cmd.none
            )


handleReceivedCardDValue : D.Value -> Model -> Model
handleReceivedCardDValue x model =
    case D.decodeValue cardsDecoder x of
        Ok serverCards ->
            handleNewGameCards serverCards model

        Err _ ->
            Debug.todo "SHFAAAAACK"


handleNewGameCards : List GameCard -> Model -> Model
handleNewGameCards serverCards model =
    case model.gameStatus of
        WaitingOnCardsFromServer ->
            let
                updated_cards =
                    List.map A.init serverCards
            in
            { model | cards = updated_cards, gameStatus = Playing Audience }

        ATeamWon _ ->
            { model | cards = List.map A.init serverCards, gameStatus = Playing Audience }

        Playing _ ->
            let
                updated_cards =
                    updateCardsToLatest serverCards model.cards

                updated_status =
                    updateStatusFromCards serverCards model.gameStatus
            in
            { model | cards = updated_cards, gameStatus = updated_status }


updateStatusFromCards : List GameCard -> GameStatus -> GameStatus
updateStatusFromCards cards currentStatus =
    if List.filter isRedCard cards |> List.all isTurned then
        ATeamWon Red

    else if List.filter isBlueCard cards |> List.all isTurned then
        ATeamWon Blue

    else
        currentStatus


isTurned : GameCard -> Bool
isTurned card =
    case card.turnedStatus of
        Turned _ ->
            True

        UnTurned ->
            False


isBlueCard : GameCard -> Bool
isBlueCard { originallyColored } =
    originallyColored == Blue


isRedCard : GameCard -> Bool
isRedCard { originallyColored } =
    originallyColored == Red


updateCardsToLatest : List GameCard -> List (A.Timeline GameCard) -> List (A.Timeline GameCard)
updateCardsToLatest freshFromServerCards existingCards =
    List.map
        (\existingCard ->
            let
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
    div [ id "board-container", class "board-container" ] <|
        [ cardsView model.window model.cards model.gameStatus
        , gameFinishedPrompt model.gameStatus
        , switchToCodeGiverView model.gameStatus
        , Firework.view model.firework
        ]
            ++ scoreboards model


scoreboards model =
    case model.gameStatus of
        Playing Audience ->
            [ redScoreBoardView model.cards
            , blueScoreBoardView model.cards
            ]

        _ ->
            []


howManyUnTurnedCardsOfATeam : Team -> List GameCard -> Int
howManyUnTurnedCardsOfATeam team cards =
    cards
        |> List.filter ((==) team << .originallyColored)
        |> List.filter isUnTurned
        |> List.length


blueScoreBoardView cards =
    let
        howManyUnTurneds =
            howManyUnTurnedCardsOfATeam Blue (List.map A.current cards)
    in
    div
        [ class "blue-sb sb"
        , style "right" "16px"
        , onClick <| Detonate Blue
        , style "background-color" (Color.toCssString <| teamToColor Blue)
        ]
        [ text <| String.fromInt howManyUnTurneds ]


redScoreBoardView cards =
    let
        howManyUnTurneds =
            howManyUnTurnedCardsOfATeam Red (List.map A.current cards)
    in
    div
        [ class "red-sb sb"
        , style "left" "16px"
        , onClick <| Detonate Red
        , style "background-color" (Color.toCssString <| teamToColor Red)
        ]
        [ text <| String.fromInt howManyUnTurneds ]


type alias Window =
    { width : Int
    , height : Int
    }


calcCardWidth fullWidth columns =
    let
        reservedEdgesOfScreen =
            16

        -- the full gap between cards
        -- each card would have a margin of (propMarginConstant / 2)
        propMarginConstant =
            8
    in
    ((fullWidth - reservedEdgesOfScreen) - (propMarginConstant * (columns - 1))) // columns


calcCardHeight : Int -> Int -> Int
calcCardHeight fullHeight rows =
    let
        toolbarReserve =
            56 + 160

        -- the full gap between cards
        -- each card would have a margin of (propMarginConstant / 2)
        propMarginConstant =
            8
    in
    ((fullHeight - toolbarReserve) - (propMarginConstant * (rows - 1))) // rows


switchToCodeGiverView : GameStatus -> Html Msg
switchToCodeGiverView gameStatus =
    case gameStatus of
        WaitingOnCardsFromServer ->
            text ""

        Playing Audience ->
            button [ class "switch-to-codegiver", onClick UserClickedSwitchToCodegiver ]
                [ text "Switch to Giving Codes" ]

        Playing CodeGiver ->
            button [ class "switch-to-codegiver", onClick UserClickedSwitchToAudience ]
                [ text "Switch to Audience View" ]

        ATeamWon _ ->
            text ""


gameFinishedPrompt gameStatus =
    case gameStatus of
        WaitingOnCardsFromServer ->
            text ""

        Playing _ ->
            text ""

        ATeamWon team ->
            div [ class <| "finished-prompt " ++ teamToString team ]
                [ h1 [ class "team-won" ] [ text <| "yay " ++ teamToString team ++ " team won" ]

                --, img [ class "win-gif", src "https://media.giphy.com/media/aZXRIHxo9saPe/giphy.gif" ] []
                , button [ class "restart-game", onClick UserClickedRestartGame ] [ text "PLAY AGAIN" ]
                ]


flip f y x =
    f x y


findCardByHash : Hash -> List GameCard -> Maybe GameCard
findCardByHash hash oldies =
    List.find (flip cardMatchesHash hash) oldies


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


cardsView : Window -> List (A.Timeline GameCard) -> GameStatus -> Html Msg
cardsView window cards gameStatus =
    div [ class "cards noselect" ] <|
        case gameStatus of
            Playing Audience ->
                List.indexedMap (audienceCardView window) cards

            Playing CodeGiver ->
                List.indexedMap codeGiverCardView cards

            _ ->
                []


codeGiverCardView : Int -> A.Timeline GameCard -> Html Msg
codeGiverCardView count timelineCard =
    let
        currentCard =
            A.current timelineCard
    in
    div
        [ class "card "
        , Animator.Inline.backgroundColor timelineCard <|
            \state ->
                if isUnTurned state then
                    teamToColor currentCard.originallyColored

                else
                    Color.orange
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
            [ text currentCard.word ]
        ]


calcCardHeightWidth : Window -> ( Int, Int )
calcCardHeightWidth window =
    let
        howManyPerRow =
            if window.width < 351 then
                3

            else if window.width < 500 then
                4

            else
                5

        howManyColumns =
            calcHowManyColumns howManyPerRow 20
    in
    ( calcCardHeight window.height howManyColumns
    , calcCardWidth window.width howManyPerRow
    )


calcHowManyColumns rows hardCodedNumberOfCards =
    let
        divResult =
            20 // rows

        remainderResult =
            remainderBy rows 20
    in
    if remainderResult > 0 then
        divResult + 1

    else
        divResult


audienceCardView : Window -> Int -> A.Timeline GameCard -> Html Msg
audienceCardView window count timelineCard =
    let
        currentCard =
            A.current timelineCard

        hash =
            currentCard.hash

        ( cardHeight, cardWidth ) =
            calcCardHeightWidth window

        buttonOrDiv =
            if A.current timelineCard |> ((==) UnTurned << .turnedStatus) then
                button

            else
                div
    in
    buttonOrDiv
        [ class "card "
        , Html.Attributes.style "height" (String.fromInt cardHeight ++ "px")
        , Html.Attributes.style "width" (String.fromInt cardWidth ++ "px")
        , Animator.Inline.backgroundColor timelineCard <|
            \state ->
                if isUnTurned state then
                    Color.rgb255 230 233 237

                else
                    teamToColor currentCard.originallyColored
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
            [ text currentCard.word ]
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


subscriptions model =
    Sub.batch
        [ A.toSubscription Tick model (animator model)
        , Browser.Events.onResize WindowSize
        , System.sub [] ParticleMsg model.firework
        ]



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
        word
        original_color
        (Hash hash)


funky4 : String -> Team -> Team -> String -> GameCard
funky4 hash turnedOverBy original_color word =
    GameCard (Turned turnedOverBy)
        word
        original_color
        (Hash hash)


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


cardBelongsToTeam : GameCard -> Team -> Bool
cardBelongsToTeam card team =
    card.originallyColored == team


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
