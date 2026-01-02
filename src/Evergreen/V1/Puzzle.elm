module Evergreen.V1.Puzzle exposing (..)


type alias Dimensions =
    { width : Int
    , height : Int
    }


type alias Cell =
    { answer : Maybe String
    , label : Maybe Int
    , cellType : Maybe Int
    }


type alias Clue =
    { label : String
    , direction : String
    , text : String
    }


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
