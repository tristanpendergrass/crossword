module Backend exposing (..)

import Http
import Json.Decode as D
import Json.Encode as E
import Lamdera exposing (ClientId, SessionId, broadcast, sendToFrontend)
import Puzzle
import Task
import Time
import Types exposing (..)


type alias Model =
    BackendModel


app =
    Lamdera.backend
        { init = init
        , update = update
        , updateFromFrontend = updateFromFrontend
        , subscriptions = subscriptions
        }


init : ( Model, Cmd BackendMsg )
init =
    ( { currentPuzzleId = Nothing
      , lastFetchDate = Nothing
      , lastError = Nothing
      , fetchStatus = "Starting up..."
      }
    , Task.perform CheckForNewPuzzle Time.now
    )


subscriptions : Model -> Sub BackendMsg
subscriptions _ =
    -- Check every hour if we need a new puzzle
    Time.every (60 * 60 * 1000) CheckForNewPuzzle


update : BackendMsg -> Model -> ( Model, Cmd BackendMsg )
update msg model =
    case msg of
        CheckForNewPuzzle posix ->
            let
                date =
                    formatDate posix
            in
            if model.lastFetchDate == Just date then
                -- Already fetched today's puzzle
                ( { model | fetchStatus = "Already have puzzle for " ++ date }, Cmd.none )

            else
                -- Fetch today's puzzle (set lastFetchDate early to prevent concurrent fetches)
                ( { model
                    | lastFetchDate = Just date
                    , fetchStatus = "Fetching NYT puzzle for " ++ date ++ "..."
                  }
                , fetchNytPuzzle date
                )

        GotNytPuzzle date result ->
            case result of
                Ok puzzle ->
                    -- Convert to iPuz and upload to squares.io
                    ( { model | lastError = Nothing, fetchStatus = "Got NYT puzzle, uploading to squares.io..." }
                    , uploadToSquares date puzzle
                    )

                Err err ->
                    ( { model
                        | lastFetchDate = Nothing
                        , lastError = Just ("NYT fetch failed for " ++ date ++ ": " ++ httpErrorToString err)
                        , fetchStatus = "NYT fetch failed"
                      }
                    , Cmd.none
                    )

        GotSquaresResponse date result ->
            case result of
                Ok puzzleId ->
                    let
                        status =
                            "Puzzle ready! ID: " ++ puzzleId
                    in
                    ( { model
                        | currentPuzzleId = Just puzzleId
                        , lastFetchDate = Just date
                        , lastError = Nothing
                        , fetchStatus = status
                      }
                    , broadcast (CurrentPuzzle (Just puzzleId) Nothing status)
                    )

                Err err ->
                    ( { model
                        | lastFetchDate = Nothing
                        , lastError = Just ("Squares.io upload failed: " ++ httpErrorToString err)
                        , fetchStatus = "Squares.io upload failed"
                      }
                    , Cmd.none
                    )


updateFromFrontend : SessionId -> ClientId -> ToBackend -> Model -> ( Model, Cmd BackendMsg )
updateFromFrontend _ clientId msg model =
    case msg of
        GetCurrentPuzzle ->
            ( model
            , sendToFrontend clientId (CurrentPuzzle model.currentPuzzleId model.lastError model.fetchStatus)
            )


httpErrorToString : Http.Error -> String
httpErrorToString err =
    case err of
        Http.BadUrl url ->
            "Bad URL: " ++ url

        Http.Timeout ->
            "Request timed out"

        Http.NetworkError ->
            "Network error"

        Http.BadStatus status ->
            "Bad status: " ++ String.fromInt status

        Http.BadBody body ->
            "Bad body: " ++ body



-- HTTP Requests


fetchNytPuzzle : String -> Cmd BackendMsg
fetchNytPuzzle date =
    Http.request
        { method = "GET"
        , headers =
            [ Http.header "X-Games-Auth-Bypass" "true"
            ]
        , url = "https://www.nytimes.com/svc/crosswords/v6/puzzle/daily/" ++ date ++ ".json"
        , body = Http.emptyBody
        , expect = Http.expectJson (GotNytPuzzle date) Puzzle.nytPuzzleDecoder
        , timeout = Just 30000
        , tracker = Nothing
        }


uploadToSquares : String -> Puzzle.NytPuzzle -> Cmd BackendMsg
uploadToSquares date puzzle =
    let
        ipuzJson =
            E.encode 0 (Puzzle.toIpuz puzzle)

        body =
            Http.multipartBody
                [ Http.stringPart "data" "{\"options\":{}}"
                , Http.stringPart "puz" ipuzJson
                , Http.stringPart "v" "2"
                ]
    in
    Http.request
        { method = "POST"
        , headers =
            [ Http.header "User-Agent" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            , Http.header "Origin" "https://squares.io"
            , Http.header "Referer" "https://squares.io/"
            ]
        , url = "https://squares.io/api/1/puzzle"
        , body = body
        , expect = Http.expectJson (GotSquaresResponse date) squaresResponseDecoder
        , timeout = Just 30000
        , tracker = Nothing
        }


squaresResponseDecoder : D.Decoder String
squaresResponseDecoder =
    D.at [ "pids" ] (D.index 0 D.string)



-- Date formatting


{-| Pacific Standard Time (UTC-8)
-}
pacificTime : Time.Zone
pacificTime =
    Time.customZone (-8 * 60) []


{-| Adjust the date for the active puzzle:

  - Monday → Saturday's puzzle
  - Saturday → Friday's puzzle
  - Other days → that day's puzzle

-}
activePuzzleDate : Time.Posix -> Time.Posix
activePuzzleDate posix =
    let
        dayInMs =
            24 * 60 * 60 * 1000

        adjustment =
            case Time.toWeekday pacificTime posix of
                Time.Mon ->
                    -2 * dayInMs

                Time.Sat ->
                    -1 * dayInMs

                _ ->
                    0
    in
    Time.millisToPosix (Time.posixToMillis posix + adjustment)


formatDate : Time.Posix -> String
formatDate posix =
    let
        adjustedPosix =
            activePuzzleDate posix

        year =
            String.fromInt (Time.toYear pacificTime adjustedPosix)

        month =
            String.padLeft 2 '0' (String.fromInt (monthToInt (Time.toMonth pacificTime adjustedPosix)))

        day =
            String.padLeft 2 '0' (String.fromInt (Time.toDay pacificTime adjustedPosix))
    in
    year ++ "-" ++ month ++ "-" ++ day


monthToInt : Time.Month -> Int
monthToInt month =
    case month of
        Time.Jan ->
            1

        Time.Feb ->
            2

        Time.Mar ->
            3

        Time.Apr ->
            4

        Time.May ->
            5

        Time.Jun ->
            6

        Time.Jul ->
            7

        Time.Aug ->
            8

        Time.Sep ->
            9

        Time.Oct ->
            10

        Time.Nov ->
            11

        Time.Dec ->
            12