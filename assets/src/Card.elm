module Card exposing (..)

-- Card should be monoidal for the comprehensive game
-- who flipped, originalColor, unique Identifier yada yada

import Element exposing (..)
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)


type Card
    = UnTurned Word OriginallyColored Hash
    | Turned Word TurnedOverBy OriginallyColored Hash


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
    UnTurned (Word word) (OriginallyColored original_color) (Hash hash)


funky4 : String -> Team -> Team -> String -> Card
funky4 hash turnedOverBy original_color word =
    Turned (Word word) (TurnedOverBy turnedOverBy) (OriginallyColored original_color) (Hash hash)


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


cardMatchesHash : Card -> Hash -> Bool
cardMatchesHash card hash1 =
    case card of
        UnTurned _ _ hash2 ->
            hashesAreEqual hash1 hash2

        Turned _ _ _ hash2 ->
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


initialCards =
    [ UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Blue)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored Red)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    , UnTurned (Word "testing") (OriginallyColored NoTeam)
    ]
        |> List.indexedMap (\_ y -> y (Hash "darn"))


turnOverCard turningOverTeam card =
    case card of
        UnTurned word originallyColored hash ->
            Turned word (TurnedOverBy turningOverTeam) originallyColored hash

        Turned _ _ _ _ ->
            Debug.todo "OH MY GOD"


getTeamColor team =
    case team of
        Red ->
            rgb255 255 0 0

        Blue ->
            rgb255 0 0 255

        NoTeam ->
            rgb255 60 60 60
