module Game exposing (..)

import Animation exposing (deg, px)
import Animation.Messenger exposing (State)
import Browser
import Browser.Dom as Dom
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
    { cards : List Card
    , boardStyle : Animation.Messenger.State Msg
    }


initModel =
    { cards = []
    , boardStyle = initBoardStyle
    }


initBoardStyle =
    Animation.style [ Animation.scale 1, Animation.translate (px 0) (px 0) ]


init : () -> ( Model, Cmd Msg )
init _ =
    ( initModel
    , Cmd.none
    )


type Card
    = UnTurned (State Msg) Word OriginallyColored Hash
    | Turned (State Msg) Word TurnedOverBy OriginallyColored Hash



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = ReceivedCardsFromServer D.Value
    | Animate Animation.Msg
    | ZoomedInReadyToTurn Hash
    | TurnedReadyToZoomOut
    | FoundElementsReadyToZoomIn (Result Dom.Error ContainerToTranslate)
    | UserClickedOnHash Hash


type ContainerToTranslate
    = ContainerToTranslate Float Float Hash


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        UserClickedOnHash hash ->
            ( model, alsoToSocket <| encodeHash hash )

        FoundElementsReadyToZoomIn x ->
            case x of
                Err _ ->
                    ( model, Cmd.none )

                Ok containerToTranslate ->
                    ( { model
                        | boardStyle = updateBoardStyle containerToTranslate model.boardStyle
                      }
                    , Cmd.none
                    )

        Animate animMsg ->
            let
                ( updatedCards, cardCmds ) =
                    List.foldl (mapStyle animMsg) ( [], [] ) model.cards

                ( updatedBoard, boardCmd ) =
                    Animation.Messenger.update animMsg model.boardStyle
            in
            ( { model | cards = updatedCards, boardStyle = updatedBoard }
            , Cmd.batch <| boardCmd :: cardCmds
            )

        TurnedReadyToZoomOut ->
            let
                updatedBoardStyle =
                    Animation.queue
                        [ Animation.to
                            [ Animation.scale 1
                            , Animation.translate (px 0) (px 0)
                            ]
                        ]
                        model.boardStyle
            in
            ( { model | boardStyle = updatedBoardStyle }, Cmd.none )

        ZoomedInReadyToTurn hash ->
            let
                updatedCards =
                    manuallyTurnCardByHash model.cards hash
            in
            ( { model | cards = updatedCards }, Cmd.none )

        ReceivedCardsFromServer x ->
            decodeCardsFromServer model x


decodeCardsFromServer model x =
    case D.decodeValue cardsDecoder x of
        Ok decoded_thing ->
            let
                ( updatedCards, maybeHash ) =
                    transferOverStyles model.cards decoded_thing

                boardCmd =
                    Maybe.unwrap Cmd.none updateBoardCmd maybeHash
            in
            ( { model | cards = updatedCards }, boardCmd )

        Err e ->
            ( model, Cmd.none )


updateBoardCmd : Hash -> Cmd Msg
updateBoardCmd hash =
    let
        f hash2 turnedElement middleElement =
            ContainerToTranslate
                (middleElement.element.x - turnedElement.element.x)
                (middleElement.element.y - turnedElement.element.y)
                hash2
    in
    Task.attempt FoundElementsReadyToZoomIn <|
        Task.map3 f
            (Task.succeed hash)
            (Dom.getElement <| hashToIdSelectorString hash)
            (Dom.getElement "middle12")


updateBoardStyle : ContainerToTranslate -> Animation.Messenger.State Msg -> Animation.Messenger.State Msg
updateBoardStyle (ContainerToTranslate x y hash) boardStyle =
    Animation.queue
        [ Animation.to [ Animation.scale 1, Animation.translate (px 0) (px 0) ]
        , Animation.to [ Animation.translate (px x) (px y), Animation.scale 4 ]
        , Animation.Messenger.send <| ZoomedInReadyToTurn hash
        ]
        boardStyle


manuallyTurnCardByHash cards hashToTurn =
    List.map
        (\card ->
            if cardMatchesHash card hashToTurn then
                case card of
                    UnTurned style word oc hash ->
                        Turned (Animation.queue getTurnt style) word (TurnedOverBy Red) oc hash

                    Turned style word turnedOverBy oc hash ->
                        Turned (Animation.queue getTurnt style) word (TurnedOverBy Red) oc hash

            else
                card
        )
        cards



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ -- div [ class "score-container" ] <| scoreView model.cards,
          div [ class "outer-board" ]
            [ div (Animation.render model.boardStyle ++ [ id "board-container", class "board-container" ])
                [ div [ class "cards noselect" ] <| List.indexedMap cardView model.cards
                ]
            ]
        ]


wiggleWidIt =
    [ SpecificWiggle 200 (px 1) (px 1) (deg 0)
    , SpecificWiggle 150 (px -1) (px -2) (deg -1)
    , SpecificWiggle 100 (px -3) (px 0) (deg 1)
    , SpecificWiggle 80 (px 3) (px 2) (deg 0)
    , SpecificWiggle 70 (px 1) (px -1) (deg 1)
    , SpecificWiggle 70 (px 0) (px 1) (deg -1)
    , SpecificWiggle 70 (px -1) (px 0) (deg 1)
    , SpecificWiggle 70 (px 2) (px 1) (deg 1)
    , SpecificWiggle 60 (px -1) (px -2) (deg -1)
    , SpecificWiggle 50 (px -3) (px 1) (deg 0)
    , SpecificWiggle 50 (px 3) (px 1) (deg -1)
    , SpecificWiggle 50 (px -1) (px -1) (deg 1)
    , SpecificWiggle 50 (px 1) (px 2) (deg 0)
    , SpecificWiggle 50 (px 1) (px -2) (deg -1)
    , SpecificWiggle 50 (px 0) (px 0) (deg 0)
    ]
        |> List.map
            (\(SpecificWiggle dur transX transY rotDeg) ->
                Animation.toWith
                    (Animation.easing { duration = dur, ease = \x -> x })
                    [ Animation.translate transX transY, Animation.rotate rotDeg ]
            )


getTurnt =
    wiggleWidIt
        ++ [ Animation.to [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]
           , Animation.Messenger.send TurnedReadyToZoomOut
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


cardView : Int -> Card -> Html Msg
cardView count card =
    case card of
        UnTurned style (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card "
                , onClick <| UserClickedOnHash hash
                , id <| "middle" ++ String.fromInt count
                ]
                [ div (Animation.render style ++ [ class "card-inner", id <| hashToIdSelectorString hash ])
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class "card-back " ] []
                    ]
                ]

        Turned style (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) hash ->
            div
                [ class <| "card"
                , id <| "middle" ++ String.fromInt count
                ]
                [ div (Animation.render style ++ [ class "card-inner", id <| hashToIdSelectorString hash ])
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class <| "card-back audience-" ++ teamToString originallyColoredTeam ] [ span [ class "word" ] [ text word ] ]
                    ]
                ]



-- ---------------------------
-- MAIN
-- ---------------------------


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
        [ Animation.subscription Animate (List.map cardToItsStyle model.cards ++ [ model.boardStyle ])
        ]



-- ---------------------------
-- DECODERS
-- ---------------------------


cardsDecoder =
    D.list cardDecoder


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


funky : String -> Team -> String -> Card
funky hash original_color word =
    UnTurned unturnt
        (Word word)
        (OriginallyColored original_color)
        (Hash hash)


funky4 : String -> Team -> Team -> String -> Card
funky4 hash turnedOverBy original_color word =
    Turned defaultTurnt (Word word) (TurnedOverBy turnedOverBy) (OriginallyColored original_color) (Hash hash)


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


isUnTurned : Card -> Bool
isUnTurned card =
    case card of
        UnTurned _ _ _ _ ->
            True

        _ ->
            False


mapStyle : Animation.Msg -> Card -> ( List Card, List (Cmd Msg) ) -> ( List Card, List (Cmd Msg) )
mapStyle animMsg card ( cardsAcc, cmdAcc ) =
    case card of
        UnTurned style w oc h ->
            let
                ( updatedStyle, cardCmd ) =
                    Animation.Messenger.update animMsg style
            in
            ( cardsAcc ++ [ UnTurned updatedStyle w oc h ], cardCmd :: cmdAcc )

        Turned style w tob oc h ->
            let
                ( updatedStyle, cardCmd ) =
                    Animation.Messenger.update animMsg style
            in
            ( cardsAcc ++ [ Turned updatedStyle w tob oc h ], cardCmd :: cmdAcc )


transferOverStyles : List Card -> List Card -> ( List Card, Maybe Hash )
transferOverStyles oldCards newCards =
    List.map
        (\new ->
            case List.find (sameCard new) oldCards of
                Just old ->
                    case old of
                        UnTurned style word oc hash ->
                            case new of
                                Turned _ _ _ _ _ ->
                                    ( Turned style word (TurnedOverBy Red) oc hash, Just hash )

                                _ ->
                                    ( old, Nothing )

                        _ ->
                            ( old, Nothing )

                Nothing ->
                    ( new, Nothing )
        )
        newCards
        |> List.foldl
            (\( card, whatever ) ( cards, turnedCard ) ->
                case turnedCard of
                    Just x ->
                        ( cards ++ [ card ], Just x )

                    Nothing ->
                        ( cards ++ [ card ], whatever )
            )
            ( [], Nothing )


type SpecificWiggle
    = SpecificWiggle Float Animation.Length Animation.Length Animation.Angle


cardBelongsToTeam : Card -> Team -> Bool
cardBelongsToTeam card team =
    case card of
        UnTurned _ _ (OriginallyColored teamCheck) _ ->
            team == teamCheck

        Turned _ _ _ (OriginallyColored teamCheck) _ ->
            team == teamCheck


sameCard : Card -> Card -> Bool
sameCard c1 c2 =
    case c1 of
        UnTurned _ _ _ hash ->
            cardMatchesHash c2 hash

        Turned _ _ _ _ hash ->
            cardMatchesHash c2 hash


cardMatchesHash : Card -> Hash -> Bool
cardMatchesHash card hash1 =
    case card of
        UnTurned _ _ _ hash2 ->
            hashesAreEqual hash1 hash2

        Turned _ _ _ _ hash2 ->
            hashesAreEqual hash1 hash2


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


cardToItsStyle card =
    case card of
        UnTurned style _ _ _ ->
            style

        Turned style _ _ _ _ ->
            style


teamToString team =
    case team of
        Red ->
            "red"

        Blue ->
            "blue"

        NoTeam ->
            "gray"
