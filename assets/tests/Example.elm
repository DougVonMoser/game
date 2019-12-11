module Example exposing (..)

import Card exposing (..)
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Decode as D exposing (Decoder, at, string)
import Json.Encode as E exposing (Value)
import Main exposing (..)
import Test exposing (..)
import Test.Html.Query as Query
import Test.Html.Selector exposing (tag, text)


unitTest : Test
unitTest =
    describe "cardDecoder"
        [ test "decodes turned" <|
            \() ->
                """{
                    "hash": "IMAHASH", 
                    "original_color": "gray", 
                    "turned_over_by": "red", 
                    "word": "porro"
                }"""
                    |> D.decodeString cardDecoder
                    |> Expect.equal (Ok (Turned (Word "porro") (TurnedOverBy Red) (OriginallyColored NoTeam) (Hash "IMAHASH")))
        , test "decodes unturned" <|
            \() ->
                """{
                    "hash": "IMAHASH", 
                    "original_color": "gray", 
                    "turned_over_by": null, 
                    "word": "porro"
                }"""
                    |> D.decodeString cardDecoder
                    |> Expect.equal (Ok (UnTurned (Word "porro") (OriginallyColored NoTeam) (Hash "IMAHASH")))
        ]
