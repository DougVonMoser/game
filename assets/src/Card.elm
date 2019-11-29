module Card exposing (..)

-- Card should be monoidal for the comprehensive game
-- who flipped, originalColor, unique Identifier yada yada

import Element exposing (..)


type Card
    = UnTurned Word OriginallyColored Hash
    | Turned Word TurnedOverBy OriginallyColored Hash



--unique identifier


type Hash
    = Hash Int


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
        |> List.indexedMap (\x y -> y (Hash x))


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
