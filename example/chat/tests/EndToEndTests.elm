module EndToEndTests exposing (main, suite)

import Backend
import Effect.Browser.Dom as Dom
import Effect.Command as Command exposing (BackendOnly, Command, FrontendOnly)
import Effect.Http exposing (Response(..))
import Effect.Lamdera
import Effect.Subscription as Subscription
import Effect.Test exposing (FileUpload(..), HttpResponse(..), MultipleFilesUpload(..))
import Effect.Time
import Frontend
import Html
import Test exposing (Test)
import Test.Html.Query
import Test.Html.Selector
import Types exposing (BackendModel, BackendMsg, FrontendModel, FrontendMsg, ToBackend, ToFrontend)
import Url exposing (Url)


unsafeUrl : Url
unsafeUrl =
    case Url.fromString "https://chat-app.lamdera.app" of
        Just url ->
            url

        Nothing ->
            Debug.todo "Invalid url"


config : Effect.Test.Config ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel
config =
    { frontendApp = Frontend.app_
    , backendApp = Backend.app_
    , handleHttpRequest = always NetworkErrorResponse
    , handlePortToJs = always Nothing
    , handleFileUpload = always UnhandledFileUpload
    , handleMultipleFilesUpload = always UnhandledMultiFileUpload
    , domain = unsafeUrl
    }


mobileViewport =
    { width = 414, height = 895 }


tests : List (Effect.Test.EndToEndTest ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
tests =
    [ Effect.Test.start
        "Two clients chatting back and forth"
        (Effect.Time.millisToPosix 0)
        config
        [ Effect.Test.connectFrontend
            100
            (Effect.Lamdera.sessionIdFromString "sessionId0")
            "/"
            mobileViewport
            (\alice ->
                [ -- Alice (client 0) sends first message
                  alice.input 100 (Dom.id "message-input") "Hey! Anyone here?"
                , alice.click 100 (Dom.id "send-button")
                , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Hey! Anyone here?" ])
                , -- Bob (client 1) connects
                  Effect.Test.connectFrontend
                    100
                    (Effect.Lamdera.sessionIdFromString "sessionId1")
                    "/"
                    mobileViewport
                    (\bob ->
                        [ -- Bob should see Alice's message in history
                          bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Hey! Anyone here?" ])
                        , -- Bob introduces himself
                          bob.input 100 (Dom.id "message-input") "Hi! I'm Bob, just joined"
                        , bob.click 100 (Dom.id "send-button")
                        , bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Hi! I'm Bob, just joined" ])
                        , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Hi! I'm Bob, just joined" ])
                        , -- Alice welcomes Bob
                          alice.input 100 (Dom.id "message-input") "Welcome Bob! I'm Alice"
                        , alice.click 100 (Dom.id "send-button")
                        , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Welcome Bob! I'm Alice" ])
                        , bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Welcome Bob! I'm Alice" ])
                        , -- Bob asks a question
                          bob.input 100 (Dom.id "message-input") "Nice to meet you! What brings you here?"
                        , bob.click 100 (Dom.id "send-button")
                        , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Nice to meet you! What brings you here?" ])
                        , bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Nice to meet you! What brings you here?" ])
                        , -- Alice responds
                          alice.input 100 (Dom.id "message-input") "Testing this cool chat app!"
                        , alice.click 100 (Dom.id "send-button")
                        , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Testing this cool chat app!" ])
                        , bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Testing this cool chat app!" ])
                        , -- Bob agrees
                          bob.input 100 (Dom.id "message-input") "Awesome! The side-by-side view is great"
                        , bob.click 100 (Dom.id "send-button")
                        , alice.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Awesome! The side-by-side view is great" ])
                        , bob.checkView 100 (Test.Html.Query.has [ Test.Html.Selector.text "Awesome! The side-by-side view is great" ])
                        ]
                    )
                ]
            )
        ]
    ]


suite : Test
suite =
    tests
        |> List.map Effect.Test.toTest
        |> Test.describe "suite"


main : Program () (Effect.Test.Model ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel) (Effect.Test.Msg ToBackend FrontendMsg FrontendModel ToFrontend BackendMsg BackendModel)
main =
    Effect.Test.viewer tests
