module Frontend exposing (..)

import Browser exposing (UrlRequest(..))
import Browser.Navigation as Nav
import Html
import Html.Attributes as Attr
import Lamdera
import Types exposing (..)
import Url


type alias Model =
    FrontendModel


app =
    Lamdera.frontend
        { init = init
        , onUrlRequest = UrlClicked
        , onUrlChange = UrlChanged
        , update = update
        , updateFromBackend = updateFromBackend
        , subscriptions = \_ -> Sub.none
        , view = view
        }


init : Url.Url -> Nav.Key -> ( Model, Cmd FrontendMsg )
init _ key =
    ( { key = key
      , puzzleUrl = Nothing
      , error = Nothing
      , status = "Connecting..."
      }
    , Lamdera.sendToBackend GetCurrentPuzzle
    )


update : FrontendMsg -> Model -> ( Model, Cmd FrontendMsg )
update msg model =
    case msg of
        UrlClicked urlRequest ->
            case urlRequest of
                Internal url ->
                    ( model
                    , Nav.pushUrl model.key (Url.toString url)
                    )

                External url ->
                    ( model
                    , Nav.load url
                    )

        UrlChanged _ ->
            ( model, Cmd.none )

        NoOpFrontendMsg ->
            ( model, Cmd.none )


updateFromBackend : ToFrontend -> Model -> ( Model, Cmd FrontendMsg )
updateFromBackend msg model =
    case msg of
        CurrentPuzzle maybePuzzleId maybeError status ->
            case maybePuzzleId of
                Just puzzleId ->
                    ( { model | puzzleUrl = Just (puzzleIdToUrl puzzleId), error = Nothing, status = status }
                    , Nav.load (puzzleIdToUrl puzzleId)
                    )

                Nothing ->
                    ( { model | puzzleUrl = Nothing, error = maybeError, status = status }
                    , Cmd.none
                    )


puzzleIdToUrl : String -> String
puzzleIdToUrl puzzleId =
    "https://squares.io/solve/" ++ puzzleId


view : Model -> Browser.Document FrontendMsg
view model =
    { title = "Daily Crossword"
    , body =
        [ Html.div [ Attr.style "text-align" "center", Attr.style "padding-top" "40px" ]
            [ Html.div
                [ Attr.style "font-family" "sans-serif"
                , Attr.style "padding-top" "40px"
                ]
                [ case model.puzzleUrl of
                    Just url ->
                        Html.text ("Redirecting to " ++ url ++ "...")

                    Nothing ->
                        Html.div []
                            [ Html.div [] [ Html.text ("Status: " ++ model.status) ]
                            , case model.error of
                                Just err ->
                                    Html.div [ Attr.style "color" "red", Attr.style "margin-top" "20px" ]
                                        [ Html.text ("Error: " ++ err) ]

                                Nothing ->
                                    Html.text ""
                            ]
                ]
            ]
        ]
    }