module Main exposing (main)

import Browser
import Element exposing (Element, alignRight, centerX, centerY, column, el, fill, padding, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Html exposing (Html)
import Http exposing (Error(..))
import Json.Decode as Decode
import Websocket exposing (Event(..))



-- ---------------------------
-- MODEL
-- ---------------------------


type alias Model =
    { counter : Int
    , serverMessage : String
    , socketInfo : SocketStatus
    }


type SocketStatus
    = Unopened
    | Connected Websocket.ConnectionInfo
    | Closed Int


init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags, serverMessage = "", socketInfo = Unopened }, Cmd.none )



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Msg


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    ( model, Cmd.none )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    Element.layout [] <|
        column [ spacing 80, centerX, centerY ]
            [ myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            ]


myRowOfStuff : Element msg
myRowOfStuff =
    row [ width fill, centerY, centerX, spacing 80 ]
        [ myElement
        , myElement
        , myElement
        , myElement
        , myElement
        ]


myElement : Element msg
myElement =
    el
        [ Background.color (rgb255 240 0 245)
        , Font.color (rgb255 255 255 255)
        , Border.rounded 3
        , padding 30
        ]
        (text "stylish!")



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
                { title = "Elm 0.19 starter"
                , body = [ view m ]
                }
        , subscriptions = \_ -> Sub.none
        }
