module Frontend exposing (Model, app, app_)

import Effect.Browser.Dom as Dom
import Effect.Command as Command exposing (Command, FrontendOnly)
import Effect.Lamdera exposing (ClientId)
import Effect.Subscription as Subscription
import Effect.Task
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (autofocus, id, placeholder, style, type_, value)
import Html.Events exposing (keyCode, on, onClick, onInput)
import Json.Decode as D
import Lamdera
import Types exposing (..)


type alias Model =
    FrontendModel


{-| Lamdera applications define 'app' instead of 'main'.

Lamdera.frontend is the same as Browser.application with the
additional update function; updateFromBackend.

-}
app =
    Effect.Lamdera.frontend
        Lamdera.sendToBackend
        app_


app_ =
    { init = \_ _ -> init
    , update = update
    , updateFromBackend = updateFromBackend
    , view =
        \model ->
            { title = "Lamdera chat demo"
            , body = [ view model ]
            }
    , subscriptions = \_ -> Subscription.none
    , onUrlChange = \_ -> Noop
    , onUrlRequest = \_ -> Noop
    }


init : ( Model, Command FrontendOnly ToBackend FrontendMsg )
init =
    ( { messages = [], messageFieldContent = "", clientId = Nothing }, Command.none )


{-| This is the normal frontend update function. It handles all messages that can occur on the frontend.
-}
update : FrontendMsg -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
update msg model =
    case msg of
        -- User has changed the contents of the message field
        MessageFieldChanged s ->
            ( { model | messageFieldContent = s }, Command.none )

        -- User has hit the Send button
        MessageSubmitted ->
            ( { model | messageFieldContent = "", messages = model.messages }
            , Command.batch
                [ Effect.Lamdera.sendToBackend (MsgSubmitted model.messageFieldContent)
                , focusMessageInput
                , scrollChatToBottom
                ]
            )

        -- Empty msg that does no operations
        Noop ->
            ( model, Command.none )


{-| This is the added update function. It handles all messages that can arrive from the backend.
-}
updateFromBackend : ToFrontend -> Model -> ( Model, Command FrontendOnly ToBackend FrontendMsg )
updateFromBackend msg model =
    case msg of
        HistoryReceived messages clientId ->
            ( { model | messages = messages, clientId = Just clientId }, Command.batch [ scrollChatToBottom ] )

        MessageReceived message ->
            ( { model | messages = message :: model.messages }, Command.batch [ scrollChatToBottom ] )


view : Model -> Html FrontendMsg
view model =
    div (style "padding" "10px" :: fontStyles)
        [ div
            [ style "font-size" "18px"
            , style "font-weight" "bold"
            , style "margin-bottom" "10px"
            , style "padding" "8px"
            , style "background-color" "#e0e0e0"
            , style "border-radius" "4px"
            ]
            [ text
                (case model.clientId of
                    Just clientId ->
                        "You are: " ++ String.left 8 (Effect.Lamdera.clientIdToString clientId)

                    Nothing ->
                        "Not connected"
                )
            ]
        , model.messages
            |> List.reverse
            |> List.map (viewMessage model.clientId)
            |> div
                [ id "message-box"
                , style "height" "400px"
                , style "overflow" "auto"
                , style "margin-bottom" "15px"
                , style "border" "1px solid #ccc"
                , style "padding" "5px"
                , style "background-color" "white"
                ]
        , chatInput model MessageFieldChanged
        , button (onClick MessageSubmitted :: id "send-button" :: fontStyles) [ text "Send" ]
        ]


chatInput : Model -> (String -> FrontendMsg) -> Html FrontendMsg
chatInput model msg =
    input
        ([ id "message-input"
         , type_ "text"
         , onInput msg
         , onEnter MessageSubmitted
         , placeholder "Type a message..."
         , value model.messageFieldContent
         , style "width" "300px"
         , autofocus True
         ]
            ++ fontStyles
        )
        []


viewMessage : Maybe ClientId -> ChatMsg -> Html msg
viewMessage myClientId msg =
    case msg of
        Joined clientId ->
            div [ style "font-style" "italic", style "color" "#666", style "text-align" "center", style "margin" "5px 0" ]
                [ text <| String.left 8 (Effect.Lamdera.clientIdToString clientId) ++ " joined" ]

        Left clientId ->
            div [ style "font-style" "italic", style "color" "#666", style "text-align" "center", style "margin" "5px 0" ]
                [ text <| String.left 8 (Effect.Lamdera.clientIdToString clientId) ++ " left" ]

        Message clientId message ->
            let
                isMe = Just clientId == myClientId

                bubbleStyles =
                    if isMe then
                        [ style "background-color" "#007AFF"
                        , style "color" "white"
                        , style "margin-left" "auto"
                        , style "margin-right" "8px"
                        ]
                    else
                        [ style "background-color" "#E5E5EA"
                        , style "color" "black"
                        , style "margin-right" "auto"
                        , style "margin-left" "8px"
                        ]

                commonStyles =
                    [ style "padding" "8px 12px"
                    , style "border-radius" "18px"
                    , style "margin-top" "4px"
                    , style "margin-bottom" "4px"
                    , style "max-width" "70%"
                    , style "word-wrap" "break-word"
                    , style "display" "inline-block"
                    ]
            in
            div [ style "display" "flex", style "width" "100%" ]
                [ div (bubbleStyles ++ commonStyles)
                    [ text message ]
                ]


fontStyles : List (Html.Attribute msg)
fontStyles =
    [ style "font-family" "Helvetica", style "font-size" "14px", style "line-height" "1.5" ]


scrollChatToBottom : Command FrontendOnly ToBackend FrontendMsg
scrollChatToBottom =
    Dom.getViewportOf (Dom.id "message-box")
        |> Effect.Task.andThen (\info -> Dom.setViewportOf (Dom.id "message-box") 0 info.scene.height)
        |> Effect.Task.attempt (\_ -> Noop)


focusMessageInput : Command FrontendOnly ToBackend FrontendMsg
focusMessageInput =
    Effect.Task.attempt (always Noop) (Dom.focus (Dom.id "message-input"))


onEnter : FrontendMsg -> Html.Attribute FrontendMsg
onEnter msg =
    let
        isEnter code =
            if code == 13 then
                D.succeed msg

            else
                D.fail "not ENTER"
    in
    on "keydown" (keyCode |> D.andThen isEnter)
