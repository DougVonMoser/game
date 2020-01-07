port module Main exposing (..)

import Animation exposing (deg, px)
import Animation.Messenger exposing (State)
import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick)
import Http exposing (Error(..))
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import List.Extra as List



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { counter : Int
    , serverMessage : String
    , cards : List Card
    , broadAnimations : List BroadAnimationsForATurn
    , boardStyle : Animation.Messenger.State Msg
    }


init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags
      , serverMessage = "nothing clicked yet"
      , cards = []
      , broadAnimations = []
      , boardStyle = Animation.style [ Animation.scale 1, Animation.translate (px 0) (px 0) ]
      }
    , toSocket <| E.string "connect"
    )


type Card
    = UnTurned (State Msg) Word OriginallyColored Hash
    | Turned (State Msg) Word TurnedOverBy OriginallyColored Hash


port toSocket : E.Value -> Cmd msg


port fromSocket : (D.Value -> msg) -> Sub msg



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Hey D.Value
    | Animate Animation.Msg
    | ZoomedInReadyToTurn Hash
    | TurnedReadyToZoomOut


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Animate animMsg ->
            let
                ( updatedCards, cardCmds ) =
                    List.foldl (mapStyle animMsg) ( [], [] ) model.cards

                ( updatedBoard, boardCmd ) =
                    Animation.Messenger.update animMsg model.boardStyle
            in
            ( { model | cards = updatedCards, boardStyle = updatedBoard, broadAnimations = [] }
            , Cmd.batch <| boardCmd :: cardCmds
            )

        TurnedReadyToZoomOut ->
            let
                updatedBoardStyle =
                    Animation.interrupt [ Animation.to [ Animation.scale 1, Animation.translate (px 0) (px 0) ] ]
                        model.boardStyle
            in
            ( { model | boardStyle = updatedBoardStyle }, Cmd.none )

        ZoomedInReadyToTurn hash ->
            let
                updatedCards =
                    manuallyTurnCardByHash model.cards hash

                ignore =
                    Debug.log "IA EM HERE " "cmon"
            in
            ( { model | cards = updatedCards }, Cmd.none )

        Hey x ->
            case D.decodeValue cardsDecoder x of
                Ok decoded_thing ->
                    let
                        ( updatedCards, maybeHash ) =
                            if model.cards == [] then
                                ( decoded_thing, Nothing )

                            else
                                transferOverStyles model.cards decoded_thing

                        ( updatedBoardStyle, boardCmd ) =
                            updateBoardStyle maybeHash model.boardStyle
                    in
                    ( { model | cards = updatedCards, boardStyle = updatedBoardStyle }, Cmd.none )

                Err e ->
                    Debug.todo "UH OH SPAGHHETIO"


updateBoardStyle : Maybe Hash -> Animation.Messenger.State Msg -> ( Animation.Messenger.State Msg, Cmd Msg )
updateBoardStyle maybeHash boardStyle =
    case maybeHash of
        Just hash ->
            ( Animation.interrupt
                [ Animation.to [ Animation.scale 4, Animation.translate (px 0) (px 178) ]
                , Animation.Messenger.send <| ZoomedInReadyToTurn hash
                ]
                boardStyle
            , Cmd.none
            )

        Nothing ->
            ( boardStyle, Cmd.none )



--( model, Cmd.none )


manuallyTurnCardByHash cards hashToTurn =
    List.map
        (\card ->
            if cardMatchesHash card hashToTurn then
                case card of
                    UnTurned style word oc hash ->
                        Turned (Animation.interrupt getTurnt style) word (TurnedOverBy Red) oc hash

                    Turned style word turnedOverBy oc hash ->
                        Turned (Animation.interrupt getTurnt style) word (TurnedOverBy Red) oc hash

            else
                card
        )
        cards



-- maybe this is view?


type BroadAnimationsForATurn
    = ZoomInContainer Hash
    | TurnCard Hash
    | ZoomOutContainer



-- ---------------------------
-- VIEW
-- ---------------------------


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


view : Model -> Html Msg
view model =
    div [ class "page-container" ]
        [ div [ class "score-container" ] <| scoreView model.cards
        , div [ class "outer-board" ]
            [ div (Animation.render model.boardStyle ++ [ class "board-container" ])
                [ div [ class "cards" ] <| List.map cardView model.cards
                ]
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
        UnTurned style (Word word) (OriginallyColored team) hash ->
            div
                [ class <| "card "
                ]
                [ div (Animation.render style ++ [ class "card-inner" ])
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class "card-back " ] []
                    ]
                ]

        Turned style (Word word) (TurnedOverBy turnedOverByTeam) (OriginallyColored originallyColoredTeam) _ ->
            div
                [ class <| "card"
                ]
                [ div (Animation.render style ++ [ class "card-inner" ])
                    [ div [ class "card-front" ] [ span [ class "word" ] [ text word ] ]
                    , div [ class <| "card-back audience-" ++ teamToString originallyColoredTeam ] [ span [ class "word" ] [ text word ] ]
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
        , subscriptions = subscriptions
        }


subscriptions model =
    Sub.batch
        [ fromSocket Hey
        , Animation.subscription Animate (List.map cardToItsStyle model.cards ++ [ model.boardStyle ])
        ]


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



-- {hash: "8ae375dd-d3b0-4b44-bee2-023cb7baa517", original_color: "gray", word: "voluptate"}


type Hash
    = Hash String


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



-- TURNT!
-- THESE HAVE TO COMPLEMENT EACH OTHER


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
