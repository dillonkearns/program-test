module AssertionParsingTest exposing (suite)

import Effect.Test
import Expect
import Test exposing (Test, describe, test)


suite : Test
suite =
    describe "extractAssertionFromDescription"
        [ describe "has text assertions"
            [ test "simple text assertion"
                (\_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div>
        ...
    </div>


▼ Query.has [ text "Hello, World!" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "text: \"Hello, World!\"")
                )
            , test "text with special characters"
                (\_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div></div>


▼ Query.has [ text "Hey! Anyone here?" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "text: \"Hey! Anyone here?\"")
                )
            ]
        , describe "hasNot assertions"
            [ test "does not have text"
                (\_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div>
        <p>Some content</p>
    </div>


▼ Query.hasNot [ text "Error" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "does not have text: \"Error\"")
                )
            ]
        , describe "attribute assertions"
            [ test "has attribute"
                (\_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <a href="https://example.com">Link</a>


▼ Query.has [ attribute "href" "https://example.com" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "attribute: \"href\" \"https://example.com\"")
                )
            ]
        , describe "class assertions"
            [ test "has class" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div class="active btn-primary"></div>


▼ Query.has [ class "active" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "class: \"active\"")
            ]
        , describe "style assertions"
            [ test "has style" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div style="color: red;"></div>


▼ Query.has [ style "color" "red" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "style: \"color\" \"red\"")
            ]
        , describe "tag assertions"
            [ test "has tag" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <button>Click me</button>


▼ Query.has [ tag "button" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "tag: \"button\"")
            ]
        , describe "id assertions"
            [ test "has id" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div id="main-content"></div>


▼ Query.has [ id "main-content" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "id: \"main-content\"")
            ]
        , describe "contains assertions"
            [ test "contains element" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div>
        <p>Nested</p>
    </div>


▼ Query.contains [ tag "p" ]"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal (Just "contains tag: \"p\"")
            ]
        , describe "edge cases"
            [ test "filters out Query.fromHtml lines" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml

    <div></div>"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal Nothing
            , test "filters out HTML lines" <|
                \_ ->
                    let
                        description =
                            """▼ Query.fromHtml


▼ <div>
    <p>Content</p>
</div>"""
                    in
                    Effect.Test.extractAssertionFromDescription description
                        |> Expect.equal Nothing
            ]
        ]
