module Card exposing (..)

-- Card should be monoidal for the comprehensive game
-- who flipped, originalColor, unique Identifier yada yada

import Animation exposing (State, deg, px)
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import List.Extra as List


type Card
    = UnTurned State Word OriginallyColored Hash
    | Turned State Word TurnedOverBy OriginallyColored Hash


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


mapStyle : Animation.Msg -> Card -> Card
mapStyle animMsg card =
    case card of
        UnTurned style w oc h ->
            UnTurned (Animation.update animMsg style) w oc h

        Turned style w tob oc h ->
            Turned (Animation.update animMsg style) w tob oc h


transferOverStyles : List Card -> List Card -> List Card
transferOverStyles oldCards newCards =
    List.map
        (\new ->
            case List.find (sameCard new) oldCards of
                Just old ->
                    case old of
                        UnTurned style word oc hash ->
                            case new of
                                Turned _ _ _ _ _ ->
                                    Turned (Animation.interrupt turnt style) word (TurnedOverBy Red) oc hash

                                _ ->
                                    old

                        _ ->
                            old

                Nothing ->
                    new
        )
        newCards



-- TURNT!
-- THESE HAVE TO COMPLEMENT EACH OTHER


unturnt =
    Animation.style [ Animation.rotate3d (deg 0) (deg 0) (deg 0) ]


defaultTurnt =
    Animation.style [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ]


turnt : List Animation.Step
turnt =
    [ Animation.to [ Animation.rotate3d (deg 0) (deg 180) (deg 0) ] ]


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


turnOverCard turningOverTeam card =
    case card of
        UnTurned style word originallyColored hash ->
            let
                newStyle =
                    Animation.interrupt
                        [ Animation.to
                            [ Animation.opacity 0
                            ]
                        , Animation.to
                            [ Animation.opacity 1
                            ]
                        ]
                        style
            in
            Turned newStyle word (TurnedOverBy turningOverTeam) originallyColored hash

        Turned _ _ _ _ _ ->
            Debug.todo "OH MY GOD"


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
