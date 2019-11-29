module Main exposing (main)

import Browser
import Element exposing (Element, alignRight, centerX, centerY, column, el, fill, padding, pointer, rgb255, row, spacing, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events exposing (onClick)
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



-- Card needs to be monoidal for the entire game
-- single souce of status
-- turned over by red, color blue whatnoot:kjkjkj


type Card
    = UnTurned String Team
    | Turned String Team


type Team
    = Red
    | Blue


init : Int -> ( Model, Cmd Msg )
init flags =
    ( { counter = flags, serverMessage = "nothing clicked yet", socketInfo = Unopened }, Cmd.none )



-- ---------------------------
-- UPDATE
-- ---------------------------


type Msg
    = Clicked


update : Msg -> Model -> ( Model, Cmd Msg )
update message model =
    case message of
        Clicked ->
            ( { model | serverMessage = "something got clicked" }, Cmd.none )



-- ---------------------------
-- VIEW
-- ---------------------------


view : Model -> Html Msg
view model =
    Element.layout [] <|
        column [ spacing 80, centerX, centerY ]
            [ el [] (text model.serverMessage)
            , myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            , myRowOfStuff
            ]


myRowOfStuff : Element Msg
myRowOfStuff =
    row [ width fill, centerY, centerX, spacing 80 ]
        [ myElement
        , myElement
        , myElement
        , myElement
        , myElement
        ]


myElement : Element Msg
myElement =
    el
        [ Background.color (rgb255 240 0 245)
        , Font.color (rgb255 255 255 255)
        , Border.rounded 3
        , padding 30
        , onClick Clicked
        , pointer
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
                { title = "Codenames!"
                , body = [ view m ]
                }
        , subscriptions = \_ -> Sub.none
        }
