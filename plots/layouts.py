from dash import html, dcc
import dash_bootstrap_components as dbc


def get_empty_dropdown(label, dropdown_id):
    return html.Div(
                    [
                        dbc.Label(label),
                        dcc.Dropdown(
                            id=dropdown_id,
                            options=[],
                            value=None,
                        ),
                    ]
                )


layout = html.Div(
    children=[
        dbc.Container(
            [
                html.Div(id="_dummy", hidden=True),
                html.Br(),
                html.H1("RAxML-NG version comparison"),
                html.Br(),
                dbc.Row([
                    dbc.Col(get_empty_dropdown(label="Dataset", dropdown_id="datasetSelector"),),
                    dbc.Col(get_empty_dropdown(label="RAxML-NG Command", dropdown_id="commandSelector")),
                ]),
                html.Hr(),
                html.Br(),
                html.Div([
                    html.H5("Comparison entire run"),
                    dbc.Col(get_empty_dropdown(label="Metric", dropdown_id="resultMetricSelector"),),
                    dcc.Graph(id="metricEntireRunComparison")
                ]),
                html.Br(),
                html.Div([
                    html.H5("Comparison all ML trees"),
                    dbc.Col(get_empty_dropdown(label="Metric", dropdown_id="resultMetricAllTreesSelector"),),
                    dcc.Graph(id="metricAllTreesComparison")
                ])
            ]
        )
    ]
)