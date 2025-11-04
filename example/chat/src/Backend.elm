module Backend exposing (Model, app, app_)

import Effect.Command as Command exposing (BackendOnly, Command)
import Effect.Lamdera exposing (ClientId, SessionId)
import Effect.Subscription as Subscription
import Lamdera
import Types exposing (..)


type alias Model =
    BackendModel


app =
    Effect.Lamdera.backend
        Lamdera.broadcast
        Lamdera.sendToFrontend
        app_


app_ =
    { init = init
    , update = update
    , subscriptions = subscriptions
    , updateFromFrontend = updateFromFrontend
    }


init : ( Model, Command BackendOnly ToFrontend BackendMsg )
init =
    ( { messages = [] }, Command.none )


update : BackendMsg -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
update msg model =
    case msg of
        -- A new client has joined! Send them history, and let everyone know
        ClientConnected sessionId clientId ->
            ( model
            , Command.batch
                [ Effect.Lamdera.broadcast (MessageReceived (Joined clientId))
                , Effect.Lamdera.sendToFrontend clientId (HistoryReceived model.messages clientId)
                ]
            )

        -- A client has disconnected, let everyone know
        ClientDisconnected sessionId clientId ->
            ( model, Effect.Lamdera.broadcast (MessageReceived (Left clientId)) )

        BNoop ->
            ( model, Command.none )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Command BackendOnly ToFrontend BackendMsg )
updateFromFrontend sessionId clientId msg model =
    case msg of
        -- A client has sent us a new message! Add it to our messages list, and broadcast it to everyone.
        MsgSubmitted text ->
            let
                chatMsg =
                    Message clientId (Effect.Lamdera.clientIdToString clientId ++ ": " ++ text)
            in
            ( { model | messages = chatMsg :: model.messages }
            , Effect.Lamdera.broadcast (MessageReceived chatMsg)
            )


subscriptions : Model -> Subscription.Subscription BackendOnly BackendMsg
subscriptions model =
    Subscription.batch
        [ Effect.Lamdera.onConnect ClientConnected
        , Effect.Lamdera.onDisconnect ClientDisconnected
        ]
