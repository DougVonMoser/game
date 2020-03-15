module Example exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Game exposing (..)
import Json.Decode as D exposing (Decoder, Error(..), at, string)
import Json.Encode as E exposing (Value)
import Main exposing (..)
import Test exposing (..)
import Test.Html.Query as Query
import Test.Html.Selector exposing (tag, text)


serverEventDecoderTest =
    describe "decoding events from the server"
        [ test "single player" <|
            \() ->
                ( "fake-thjingaj-adsjfkja-123jkj231kj1", "pete" )
                    |> playerDecoder
                    |> Expect.equal (Player "pete" (PlayerHash "fake-thjingaj-adsjfkja-123jkj231kj1"))
        , test "full presence state update" <|
            \() ->
                """{
                    "type": "presence_state", 
                    "value": 
                        {
                            "fake-thjingaj-adsjfkja-123jkj231kj1": {
                                "metas": [ { "online_at": "1584288812", "phx_ref": "hEr8clM71yU=" } ],
                                "name":  "pete" 
                            },
                            "fd8f758b-2c19-4d5a-9d1f-e3016ef265d3": {
                                "metas": [ { "online_at": "1584288812", "phx_ref": "hEr8clM71yU=" } ],
                                "name":  "chris" 
                            }
                        }
                }"""
                    |> D.decodeString presenceStateDecoder
                    |> Expect.equal (Ok [ Player "pete" (PlayerHash "fake-thjingaj-adsjfkja-123jkj231kj1"), Player "chris" (PlayerHash "fd8f758b-2c19-4d5a-9d1f-e3016ef265d3") ])
        ]


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
                    |> Expect.equal (Ok (Turned defaultTurnt (Word "porro") (TurnedOverBy Red) (OriginallyColored NoTeam) (Hash "IMAHASH")))
        , test "decodes unturned" <|
            \() ->
                """{
                    "hash": "IMAHASH", 
                    "original_color": "gray", 
                    "turned_over_by": null, 
                    "word": "porro"
                }"""
                    |> D.decodeString cardDecoder
                    |> Expect.equal (Ok (UnTurned unturnt (Word "porro") (OriginallyColored NoTeam) (Hash "IMAHASH")))
        ]
