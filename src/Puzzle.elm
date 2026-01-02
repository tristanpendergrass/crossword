module Puzzle exposing
    ( NytPuzzle
    , nytPuzzleDecoder
    , toIpuz
    )

import Json.Decode as D
import Json.Encode as E


type alias NytPuzzle =
    { dimensions : Dimensions
    , cells : List Cell
    , clues : List Clue
    , copyright : String
    , relatedContentUrl : String
    , editor : String
    , constructors : List String
    , publicationDate : String
    }


type alias Dimensions =
    { width : Int
    , height : Int
    }


type alias Cell =
    { answer : Maybe String
    , label : Maybe String
    , cellType : Maybe Int
    }


type alias Clue =
    { label : String
    , direction : String
    , text : String
    }


type alias IpuzClue =
    { number : Int
    , clue : String
    }



-- Cell type constants


circleType : Int
circleType =
    2


highlightType : Int
highlightType =
    3



-- JSON Decoders


nytPuzzleDecoder : D.Decoder NytPuzzle
nytPuzzleDecoder =
    D.map8 NytPuzzle
        (D.at [ "body" ] (D.index 0 (D.field "dimensions" dimensionsDecoder)))
        (D.at [ "body" ] (D.index 0 (D.field "cells" (D.list cellDecoder))))
        (D.at [ "body" ] (D.index 0 (D.field "clues" (D.list clueDecoder))))
        (D.field "copyright" D.string)
        (D.at [ "relatedContent", "url" ] D.string)
        (D.field "editor" D.string)
        (D.field "constructors" (D.list D.string))
        (D.field "publicationDate" D.string)


dimensionsDecoder : D.Decoder Dimensions
dimensionsDecoder =
    D.map2 Dimensions
        (D.field "width" D.int)
        (D.field "height" D.int)


cellDecoder : D.Decoder Cell
cellDecoder =
    D.map3 Cell
        (D.maybe (D.field "answer" D.string))
        (D.maybe (D.field "label" D.string))
        (D.maybe (D.field "type" D.int))


clueDecoder : D.Decoder Clue
clueDecoder =
    D.map3 Clue
        (D.field "label" D.string)
        (D.field "direction" D.string)
        (D.at [ "text" ] (D.index 0 (D.field "plain" D.string)))



-- Convert to iPuz format


toIpuz : NytPuzzle -> E.Value
toIpuz puzzle =
    let
        { puzzleGrid, solutionGrid } =
            buildGrids puzzle

        cluesObject =
            buildClues puzzle.clues
    in
    E.object
        [ ( "version", E.string "http://ipuz.org/v2" )
        , ( "kind", E.list E.string [ "http://ipuz.org/crossword#1" ] )
        , ( "dimensions"
          , E.object
                [ ( "width", E.int puzzle.dimensions.width )
                , ( "height", E.int puzzle.dimensions.height )
                ]
          )
        , ( "clues", cluesObject )
        , ( "puzzle", puzzleGrid )
        , ( "solution", solutionGrid )
        , ( "title", E.string "NYT Crossword" )
        , ( "copyright", E.string puzzle.copyright )
        , ( "url", E.string puzzle.relatedContentUrl )
        , ( "editor", E.string puzzle.editor )
        , ( "author", E.string (String.join " & " puzzle.constructors) )
        , ( "date", E.string puzzle.publicationDate )
        ]


buildGrids : NytPuzzle -> { puzzleGrid : E.Value, solutionGrid : E.Value }
buildGrids puzzle =
    let
        width =
            puzzle.dimensions.width

        height =
            puzzle.dimensions.height

        buildRow rowIndex =
            List.range 0 (width - 1)
                |> List.map
                    (\colIndex ->
                        let
                            cellIndex =
                                rowIndex * width + colIndex

                            cell =
                                puzzle.cells
                                    |> List.drop cellIndex
                                    |> List.head
                                    |> Maybe.withDefault { answer = Nothing, label = Nothing, cellType = Nothing }
                        in
                        ( encodePuzzleCell cell, encodeSolutionCell cell )
                    )

        rows =
            List.range 0 (height - 1)
                |> List.map buildRow

        puzzleRows =
            List.map (List.map Tuple.first) rows

        solutionRows =
            List.map (List.map Tuple.second) rows
    in
    { puzzleGrid = E.list (E.list identity) puzzleRows
    , solutionGrid = E.list (E.list E.string) solutionRows
    }


encodePuzzleCell : Cell -> E.Value
encodePuzzleCell cell =
    case cell.answer of
        Nothing ->
            -- Block cell
            E.string "#"

        Just _ ->
            let
                cellValue =
                    case cell.label of
                        Just label ->
                            label

                        Nothing ->
                            "0"

                isCircle =
                    cell.cellType == Just circleType

                isHighlight =
                    cell.cellType == Just highlightType
            in
            if isCircle || isHighlight then
                E.object
                    ([ ( "cell", E.string cellValue ) ]
                        ++ (if isCircle then
                                [ ( "style", E.object [ ( "shapebg", E.string "circle" ) ] ) ]

                            else if isHighlight then
                                [ ( "style", E.object [ ( "highlight", E.bool True ) ] ) ]

                            else
                                []
                           )
                    )

            else
                E.string cellValue


encodeSolutionCell : Cell -> String
encodeSolutionCell cell =
    case cell.answer of
        Nothing ->
            "#"

        Just answer ->
            answer


buildClues : List Clue -> E.Value
buildClues clues =
    let
        acrossClues =
            clues
                |> List.filter (\c -> c.direction == "Across")
                |> List.map encodeClue

        downClues =
            clues
                |> List.filter (\c -> c.direction == "Down")
                |> List.map encodeClue
    in
    E.object
        [ ( "Across", E.list identity acrossClues )
        , ( "Down", E.list identity downClues )
        ]


encodeClue : Clue -> E.Value
encodeClue clue =
    E.object
        [ ( "number", E.int (String.toInt clue.label |> Maybe.withDefault 0) )
        , ( "clue", E.string clue.text )
        ]
