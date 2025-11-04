module AssertionParser exposing (Assertion(..), Selector(..), fromDescription, toString)

{-| Parse elm-test Query assertion descriptions into structured data.

This module takes the description strings from elm-test's Test.Expectation
failures and parses them into a structured Assertion type, making it easier
to display assertion information in different formats.

-}


{-| Represents a Test.Html.Query assertion
-}
type Assertion
    = Has Selector
    | HasNot Selector
    | CustomLabel String


{-| Represents a Test.Html.Selector
-}
type Selector
    = Text String
    | Attribute String String
    | Class String
    | Style String String
    | Tag String


{-| Parse an elm-test failure description into a structured Assertion.

The description format from elm-test looks like:

    ▼ Query.fromHtml

        <div>
            ...
        </div>


    ▼ Query.has [ text "Hello!" ]

    ✗ has text "Hello!"

This function extracts and parses the assertion part.

-}
fromDescription : String -> Maybe Assertion
fromDescription description =
    description
        |> String.split "▼ "
        |> List.reverse
        |> List.head
        |> Maybe.map String.trim
        |> Maybe.andThen
            (\assertion ->
                -- Remove "Query.fromHtml" lines and HTML, we only want the actual assertion
                if String.startsWith "Query.fromHtml" assertion || String.startsWith "<" assertion then
                    Nothing

                else
                    -- Extract the part after "\n\n✗ has " which contains the actual assertion
                    let
                        cleanAssertion =
                            if String.contains "\n\n✗ has " assertion then
                                assertion
                                    |> String.split "\n\n✗ has "
                                    |> List.reverse
                                    |> List.head
                                    |> Maybe.withDefault assertion

                            else
                                assertion
                    in
                    parseAssertion cleanAssertion
            )


{-| Parse the cleaned assertion string into an Assertion type
-}
parseAssertion : String -> Maybe Assertion
parseAssertion str =
    -- Check if it's a hasNot assertion (starts with "not ")
    if String.startsWith "not " str then
        str
            |> String.dropLeft 4
            |> parseSelector
            |> Maybe.map HasNot

    else
        parseSelector str
            |> Maybe.map Has


{-| Parse a selector string into a Selector type
-}
parseSelector : String -> Maybe Selector
parseSelector str =
    let
        trimmed =
            str |> String.trim
    in
    -- Handle different selector types
    if String.startsWith "text " trimmed then
        trimmed
            |> String.dropLeft 5
            |> String.trim
            |> Text
            |> Just

    else if String.startsWith "attribute " trimmed then
        parseAttributeSelector trimmed

    else if String.startsWith "class " trimmed then
        trimmed
            |> String.dropLeft 6
            |> String.trim
            |> Class
            |> Just

    else if String.startsWith "tag " trimmed then
        trimmed
            |> String.dropLeft 4
            |> String.trim
            |> Tag
            |> Just

    else if String.startsWith "style " trimmed || String.startsWith "styles " trimmed then
        parseStyleSelector trimmed

    else
        Nothing


{-| Parse attribute selector like: attribute "href" "<https://example.com">
-}
parseAttributeSelector : String -> Maybe Selector
parseAttributeSelector str =
    let
        afterAttribute =
            str |> String.dropLeft 10 |> String.trim
    in
    -- Try to extract two quoted strings
    case extractTwoQuotedStrings afterAttribute of
        Just ( name, value ) ->
            Just (Attribute name value)

        Nothing ->
            Nothing


{-| Parse style selector like: style color:red or styles color:red
-}
parseStyleSelector : String -> Maybe Selector
parseStyleSelector str =
    let
        afterStyle =
            if String.startsWith "styles " str then
                str |> String.dropLeft 7 |> String.trim

            else
                str |> String.dropLeft 6 |> String.trim
    in
    -- Format is "property:value"
    case String.split ":" afterStyle of
        [ property, value ] ->
            Just (Style (String.trim property) (String.trim value))

        _ ->
            Nothing


{-| Extract two quoted strings from a string like: "foo" "bar"
-}
extractTwoQuotedStrings : String -> Maybe ( String, String )
extractTwoQuotedStrings str =
    -- Simple parser for two quoted strings
    let
        parts =
            str
                |> String.split "\""
                |> List.filter (not << String.isEmpty)
    in
    case parts of
        [ first, _, second, _ ] ->
            Just ( first, second )

        [ first, _, second ] ->
            Just ( first, second )

        _ ->
            Nothing


{-| Convert an Assertion to a human-readable string for display
-}
toString : Assertion -> String
toString assertion =
    case assertion of
        Has selector ->
            "has " ++ selectorToString selector

        HasNot selector ->
            "does not have " ++ selectorToString selector

        CustomLabel label ->
            label


{-| Convert a Selector to a string
-}
selectorToString : Selector -> String
selectorToString selector =
    case selector of
        Text value ->
            "text " ++ value

        Attribute name value ->
            "attribute " ++ name ++ " " ++ value

        Class value ->
            "class " ++ value

        Tag value ->
            "tag " ++ value

        Style property value ->
            "style " ++ property ++ ":" ++ value
