module Types exposing (..)

import Browser exposing (UrlRequest)
import Browser.Navigation exposing (Key)
import Http
import Puzzle exposing (NytPuzzle)
import Time
import Url exposing (Url)


type alias FrontendModel =
    { key : Key
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
    = UrlClicked UrlRequest
    | UrlChanged Url
    | NoOpFrontendMsg


type ToBackend
    = GetCurrentPuzzle


type BackendMsg
    = GotNytPuzzle String (Result Http.Error NytPuzzle)
    | GotSquaresResponse String (Result Http.Error String)
    | CheckForNewPuzzle Time.Posix


type ToFrontend
    = CurrentPuzzle (Maybe String) (Maybe String) String