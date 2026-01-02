module Evergreen.V1.Types exposing (..)

import Browser
import Browser.Navigation
import Evergreen.V1.Puzzle
import Http
import Time
import Url


type alias FrontendModel =
    { key : Browser.Navigation.Key
    , puzzleUrl : Maybe String
    , error : Maybe String
    , status : String
    }


type alias BackendModel =
    { currentPuzzleId : Maybe String
    , lastFetchDate : Maybe String
    , lastError : Maybe String
    , fetchStatus : String
    }


type FrontendMsg
    = UrlClicked Browser.UrlRequest
    | UrlChanged Url.Url
    | NoOpFrontendMsg


type ToBackend
    = GetCurrentPuzzle


type BackendMsg
    = GotNytPuzzle String (Result Http.Error Evergreen.V1.Puzzle.NytPuzzle)
    | GotSquaresResponse String (Result Http.Error String)
    | CheckForNewPuzzle Time.Posix


type ToFrontend
    = CurrentPuzzle (Maybe String) (Maybe String) String
