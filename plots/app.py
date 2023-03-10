from dash import Dash
import dash_bootstrap_components as dbc

external_stylesheets = [
    {
        "href": "https://use.fontawesome.com/releases/v5.8.1/css/all.css",
        "rel": "stylesheet",
        "integrity": "sha384-50oBUHEmvpQ+1lW4y57PTFmhCaXp0ML5d60M1M7uH2+nqUivzIebhndOJK28anvf",
        "crossorigin": "anonymous",
    },
    dbc.themes.FLATLY,
]

app = Dash(__name__, external_stylesheets=external_stylesheets)