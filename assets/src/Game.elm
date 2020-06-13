module Game exposing (..)

import Animator as A
import Animator.Css
import Animator.Inline
import Browser
import Browser.Dom
import Browser.Events exposing (Visibility(..))
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
import Process
import Socket exposing (..)
import Task
import Time



-- ---------------------------
-- MODEL
-- ---------------------------


type alias TimelineID =
    Int


type alias Model =
    { cards : List (A.Timeline GameCard)
    , redScoreBoard : A.Timeline SBThing
    , blueScoreBoard : A.Timeline SBThing
    , gameStatus : GameStatus
    , window : Window
    , room : String
    , firework : System Firework.Firework
    , visible : Browser.Events.Visibility
    }


type GameStatus
    = WaitingOnCardsFromServer
    | Playing AudienceOrCodeGiver
    | ATeamWon Team IsRestartButtonEnabled


type alias IsRestartButtonEnabled =
    Bool


type AudienceOrCodeGiver
    = Audience
    | CodeGiver


initModel room =
    { cards = []
    , gameStatus = WaitingOnCardsFromServer
    , redScoreBoard = A.init Static
    , blueScoreBoard = A.init Static
    , window = { width = 800, height = 500 }
    , room = room
    , firework = Firework.fireworkInit
    , visible = Visible
    }


type alias Room =
    String


init : Room -> ( Model, Cmd Msg )
init room =
    ( initModel room
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

    -- above are data we get from the server
    -- below are more for the presentation
    -- kinda weird that theyre grouped like this.. hmm..
    , dealingStatus : DealingStatus
    , timeLineID : Int
    }


type DealingStatus
    = OffScreen
    | Dealing
    | Resting


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
    | CheckForFireworks Team
    | VisibilityUpdate Visibility


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UserClickedOnHash hash ->
            case model.gameStatus of
                Playing _ ->
                    ( model, alsoToSocket <| encodeHash hash )

                _ ->
                    ( model, Cmd.none )

        UserClickedSwitchToCodegiver ->
            ( { model | gameStatus = Playing CodeGiver }, Cmd.none )

        UserClickedSwitchToAudience ->
            ( { model | gameStatus = Playing Audience }, Cmd.none )

        UserClickedRestartGame ->
            case model.gameStatus of
                ATeamWon team _ ->
                    ( { model
                        | gameStatus = ATeamWon team False
                      }
                    , restartGameSameRoom <| E.string ""
                    )

                _ ->
                    ( model, Cmd.none )

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
            handleReceivedCardDValue x model

        ParticleMsg inner ->
            ( { model
                | firework = System.update inner model.firework
              }
            , Cmd.none
            )

        CheckForFireworks team ->
            ( { model | firework = detonateTeam team model }, Cmd.none )

        VisibilityUpdate vUpdate ->
            ( { model | visible = vUpdate }, Cmd.none )


detonateTeam team model =
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
    Firework.fireworkUpdate
        model.firework
        color
        model.window


handleReceivedCardDValue : D.Value -> Model -> ( Model, Cmd Msg )
handleReceivedCardDValue x model =
    case D.decodeValue cardsDecoder x of
        Ok serverCards ->
            handleNewGameCards serverCards model

        Err _ ->
            ( model, Cmd.none )


type SBThing
    = Static
    | Pulsing Float


changeToResting : GameCard -> GameCard
changeToResting card =
    { card | dealingStatus = Resting }


changeDealingStatusTo : DealingStatus -> GameCard -> GameCard
changeDealingStatusTo newDS card =
    { card | dealingStatus = newDS }


changeToDealing card =
    { card | dealingStatus = Dealing }


initFunction : Int -> GameCard -> A.Timeline GameCard
initFunction timelineID card =
    let
        newUpdatedCard =
            { card | timeLineID = timelineID, dealingStatus = OffScreen }
    in
    A.queue
        [ A.wait (A.millis <| toFloat <| 25 * timelineID)
        , A.event (A.millis 1100) (changeDealingStatusTo Dealing newUpdatedCard)
        , A.wait (A.millis 500)
        , A.event (A.seconds 1) (changeToResting newUpdatedCard)
        ]
        (A.init newUpdatedCard)


thingyFunction timeLineOffset ( oldCard, newCard ) =
    let
        actualOldCard =
            A.current oldCard

        newCardToUse =
            { newCard | timeLineID = actualOldCard.timeLineID, dealingStatus = OffScreen }
    in
    A.queue
        [ A.event (A.seconds 1) (changeToDealing actualOldCard)
        , A.event (A.seconds 1) (changeDealingStatusTo OffScreen actualOldCard)
        , A.event A.immediately newCardToUse

        --, A.wait (A.millis <| toFloat <| 15 * timeLineOffset)
        , A.event (A.seconds 1) (changeToDealing newCardToUse)
        , A.event (A.seconds 1) (changeToResting newCardToUse)
        ]
        oldCard


handleNewGameCards : List GameCard -> Model -> ( Model, Cmd Msg )
handleNewGameCards serverCards model =
    case model.gameStatus of
        WaitingOnCardsFromServer ->
            let
                updated_cards =
                    List.indexedMap initFunction serverCards
            in
            ( { model | cards = updated_cards, gameStatus = Playing Audience }, Cmd.none )

        ATeamWon _ _ ->
            ( { model
                | cards = List.indexedMap thingyFunction (List.zip model.cards serverCards)
                , gameStatus = Playing Audience
                , redScoreBoard = A.go A.slowly Static model.redScoreBoard
                , blueScoreBoard = A.go A.slowly Static model.blueScoreBoard
              }
            , Cmd.none
            )

        Playing _ ->
            let
                updated_cards =
                    updateCardsToLatest serverCards model.cards

                updated_status =
                    updateStatusFromCards serverCards model.gameStatus

                updated_redSB =
                    calcHowFlashy serverCards Red model.redScoreBoard

                updated_blueSB =
                    calcHowFlashy serverCards Blue model.blueScoreBoard
            in
            ( { model
                | cards = updated_cards
                , gameStatus = updated_status
                , redScoreBoard = updated_redSB
                , blueScoreBoard = updated_blueSB
              }
            , Cmd.none
            )


calcHowFlashy cards team scoreboard =
    let
        count =
            howManyUnTurnedCardsOfATeam team cards
    in
    if count == 3 then
        A.go A.slowly (Pulsing 2000) scoreboard

    else if count == 2 then
        A.go A.slowly (Pulsing 1000) scoreboard

    else if count == 1 then
        A.go A.slowly (Pulsing 500) scoreboard

    else
        A.go A.immediately Static scoreboard


updateStatusFromCards : List GameCard -> GameStatus -> GameStatus
updateStatusFromCards cards currentStatus =
    if List.filter isRedCard cards |> List.all isTurned then
        ATeamWon Red True

    else if List.filter isBlueCard cards |> List.all isTurned then
        ATeamWon Blue True

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
                            let
                                updatedNewCard =
                                    { eCC
                                        | turnedStatus = newCard.turnedStatus
                                    }
                            in
                            A.go A.quickly updatedNewCard existingCard

                        False ->
                            existingCard

                Nothing ->
                    existingCard
        )
        existingCards



--- ---------------------------
--- VIEW
--- ---------------------------


view : Model -> Html Msg
view model =
    div [ id "board-container", class "board-container" ] <|
        [ cardsView model.window model.cards model.gameStatus
        , roomView model.gameStatus model.room
        , gameFinishedPrompt model.gameStatus
        , switchToCodeGiverView model.gameStatus
        , Firework.view model.firework
        ]
            ++ scoreboards model


scoreboards model =
    case model.gameStatus of
        Playing _ ->
            [ redScoreBoardView model.cards model.redScoreBoard
            , blueScoreBoardView model.cards model.blueScoreBoard
            ]

        _ ->
            []


roomView gameStatus room =
    case gameStatus of
        Playing _ ->
            div [ class "restart-game room" ] [ text <| "in room " ++ room ]

        _ ->
            text ""


howManyUnTurnedCardsOfATeam : Team -> List GameCard -> Int
howManyUnTurnedCardsOfATeam team cards =
    cards
        |> List.filter ((==) team << .originallyColored)
        |> List.filter isUnTurned
        |> List.length


blueScoreBoardView cards blueTimeline =
    let
        howManyUnTurneds =
            howManyUnTurnedCardsOfATeam Blue (List.map A.current cards)
    in
    div
        [ class "blue-sb sb"
        , style "right" "16px"
        , style "background-color" (Color.toCssString <| teamToColor Blue)
        ]
        [ span
            [ Animator.Inline.opacity blueTimeline <|
                \state ->
                    case state of
                        Static ->
                            A.at 1

                        Pulsing milliseconds ->
                            A.loop (A.millis milliseconds) (A.wave 0.25 1)
            ]
            [ text <| String.fromInt howManyUnTurneds ]
        ]


redScoreBoardView cards redTimeline =
    let
        howManyUnTurneds =
            howManyUnTurnedCardsOfATeam Red (List.map A.current cards)
    in
    div
        [ class "red-sb sb"
        , style "left" "16px"
        , style "background-color" (Color.toCssString <| teamToColor Red)
        ]
        [ span
            [ Animator.Inline.opacity redTimeline <|
                \state ->
                    case state of
                        Static ->
                            A.at 1

                        Pulsing milliseconds ->
                            A.loop (A.millis milliseconds) (A.wave 0.25 1)
            ]
            [ text <| String.fromInt howManyUnTurneds ]
        ]


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

        ATeamWon _ _ ->
            text ""


gameFinishedPrompt gameStatus =
    case gameStatus of
        WaitingOnCardsFromServer ->
            text ""

        Playing _ ->
            text ""

        ATeamWon team buttonEnabled ->
            div []
                [ button
                    [ disabled (not buttonEnabled)
                    , class "restart-game"
                    , onClick UserClickedRestartGame
                    ]
                    [ text "PLAY AGAIN" ]
                , div
                    [ class <| "sb-endgame " ++ teamToString team ++ "-background"
                    ]
                    [ text <| teamToString team ++ " wins the game!" ]
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


type alias CardPosition =
    { height : Int
    , width : Int
    , top : Int
    , left : Int
    }


cardsView : Window -> List (A.Timeline GameCard) -> GameStatus -> Html Msg
cardsView window cards gameStatus =
    div [ class "cards noselect" ] <|
        case gameStatus of
            Playing Audience ->
                List.indexedMap (audienceCardView window) cards

            Playing CodeGiver ->
                List.indexedMap (codeGiverCardView window) cards

            ATeamWon _ _ ->
                -- maybe this should be codegiverview so everyone can see the true teams cards as fireworks go
                List.indexedMap (audienceCardView window) cards

            _ ->
                []


codeGiverCardView : Window -> Int -> A.Timeline GameCard -> Html Msg
codeGiverCardView window count timelineCard =
    let
        currentCard =
            A.current timelineCard

        strikeThroughClass =
            if isUnTurned currentCard then
                ""

            else
                " strikethrough"
    in
    div
        (commonCardAttributes window count timelineCard
            ++ [ class "card "
               , Animator.Inline.backgroundColor timelineCard <|
                    \state ->
                        teamToColor currentCard.originallyColored
               ]
        )
        [ span
            [ class <| "word" ++ strikeThroughClass
            , Animator.Inline.textColor timelineCard <|
                \state ->
                    if isUnTurned state then
                        Color.black

                    else
                        Color.white
            ]
            [ text currentCard.word ]
        ]


type alias Count =
    Int


type alias Top =
    Int


type alias Left =
    Int


calcCardTopAndLeft : Window -> Count -> ( Int, Int ) -> ( Top, Left )
calcCardTopAndLeft window count ( cardHeight, cardWidth ) =
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

        whatRowAmIIn =
            if count < howManyPerRow then
                0

            else if count < (howManyPerRow * 2) then
                1

            else if count < (howManyPerRow * 3) then
                2

            else if count < (howManyPerRow * 4) then
                3

            else if count < (howManyPerRow * 5) then
                4

            else if count < (howManyPerRow * 6) then
                5

            else if count < (howManyPerRow * 7) then
                6

            else
                7

        whatColumnAmIIn =
            modBy howManyPerRow count
    in
    ( whatRowAmIIn * cardHeight + whatRowAmIIn * 8, whatColumnAmIIn * cardWidth + whatColumnAmIIn * 8 )


calcRowsColumns window =
    let
        rows =
            if window.width < 351 then
                3

            else if window.width < 500 then
                4

            else
                5

        columns =
            calcHowManyColumns rows 20
    in
    ( rows, columns )


calcCardHeightWidth : Window -> ( Int, Int )
calcCardHeightWidth window =
    let
        ( howManyPerRow, howManyColumns ) =
            calcRowsColumns window
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


px : Int -> String
px x =
    String.fromInt x ++ "px"


pxF : Float -> String
pxF x =
    String.fromFloat x ++ "px"


rotateDeg : Float -> String
rotateDeg x =
    "rotate(" ++ String.fromFloat x ++ "deg)"


calcCardMiddleLeftTop window cardWidth cardHeight =
    let
        left =
            toFloat window.width / 2 - (toFloat cardWidth / 2)

        top =
            toFloat window.height / 2 - (toFloat cardHeight / 2)
    in
    ( left, top )


commonCardAttributes window cardIndex timelineCard =
    let
        ( cardHeight, cardWidth ) =
            calcCardHeightWidth window

        ( cardTop, cardLeft ) =
            calcCardTopAndLeft window cardIndex ( cardHeight, cardWidth )

        ( cardPlaceMiddleLeft, cardPlaceMiddleTop ) =
            calcCardMiddleLeftTop window cardWidth cardHeight

        cardPlaceOffScreenTop =
            -300
    in
    [ Html.Attributes.style "height" (px cardHeight)
    , Html.Attributes.style "width" (px cardWidth)
    , Html.Attributes.style "transform"
        (rotateDeg <|
            A.move timelineCard <|
                \state ->
                    --if state.dealingStatus == Dealing then
                    --if True then
                    --A.wrap 0 360 |> A.loop (A.millis 1000)
                    --else
                    A.at 0
        )
    , Html.Attributes.style "top"
        (pxF <|
            A.linear timelineCard <|
                \state ->
                    case state.dealingStatus of
                        OffScreen ->
                            A.at cardPlaceOffScreenTop

                        Dealing ->
                            A.at cardPlaceMiddleTop

                        Resting ->
                            A.at (toFloat cardTop)
        )
    , Html.Attributes.style "left"
        (pxF <|
            A.linear timelineCard <|
                \state ->
                    case state.dealingStatus of
                        OffScreen ->
                            A.at cardPlaceMiddleLeft

                        Dealing ->
                            A.at cardPlaceMiddleLeft

                        Resting ->
                            A.at (toFloat cardLeft)
        )
    ]


audienceCardView : Window -> Int -> A.Timeline GameCard -> Html Msg
audienceCardView window count timelineCard =
    let
        currentCard =
            A.current timelineCard

        buttonOrDiv =
            if A.current timelineCard |> ((==) UnTurned << .turnedStatus) then
                button

            else
                div
    in
    buttonOrDiv
        (commonCardAttributes window count timelineCard
            ++ [ class "card "
               , onClick <| UserClickedOnHash currentCard.hash
               , Animator.Inline.backgroundColor timelineCard <|
                    \state ->
                        if isUnTurned state then
                            Color.rgb255 230 233 237

                        else
                            teamToColor currentCard.originallyColored
               ]
        )
        [ span
            [ class "word"
            , Animator.Inline.textColor timelineCard <|
                \state ->
                    if state.dealingStatus /= Resting then
                        Color.rgb255 230 233 237

                    else if isUnTurned state then
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
    List.foldl folder A.animator model.cards
        |> A.watching .redScoreBoard
            (\newSb model2 ->
                { model2 | redScoreBoard = newSb }
            )
        |> A.watching .blueScoreBoard
            (\newSb model2 ->
                { model2 | blueScoreBoard = newSb }
            )


folder : A.Timeline GameCard -> A.Animator Model -> A.Animator Model
folder gameCard y =
    A.watching
        (\model -> findTimelineGameCard model.cards gameCard)
        updateThatTimeline
        y


updateThatTimeline : A.Timeline GameCard -> Model -> Model
updateThatTimeline updatedCard model =
    let
        f old =
            if sameCardByTimelineID (A.current old) (A.current updatedCard) then
                updatedCard

            else
                old

        updated_cards =
            List.map f model.cards
    in
    { model | cards = updated_cards }


findTimelineGameCard : List (A.Timeline GameCard) -> A.Timeline GameCard -> A.Timeline GameCard
findTimelineGameCard listy x =
    case List.find (sameTimelineCard x) listy of
        Just zz ->
            zz

        Nothing ->
            x


subscriptions model =
    let
        foreverSubs =
            [ A.toSubscription Tick model (animator model)
            , Browser.Events.onResize WindowSize
            , System.sub [] ParticleMsg model.firework
            , Browser.Events.onVisibilityChange VisibilityUpdate
            ]
    in
    case ( model.gameStatus, model.visible ) of
        ( ATeamWon winningTeam _, Visible ) ->
            Sub.batch <|
                [ Time.every 30 (always (CheckForFireworks winningTeam))
                ]
                    ++ foreverSubs

        _ ->
            Sub.batch
                foreverSubs



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
        Dealing
        420


funky4 : String -> Team -> Team -> String -> GameCard
funky4 hash turnedOverBy original_color word =
    GameCard (Turned turnedOverBy)
        word
        original_color
        (Hash hash)
        Resting
        420


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


sameTimelineCard : A.Timeline GameCard -> A.Timeline GameCard -> Bool
sameTimelineCard tC1 tC2 =
    sameCardByTimelineID (A.current tC1) (A.current tC2)


sameCardByTimelineID : GameCard -> GameCard -> Bool
sameCardByTimelineID c1 c2 =
    c1.timeLineID == c2.timeLineID


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
