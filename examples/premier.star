load("render.star", "render")
load("http.star", "http")
load("encoding/base64.star", "base64")
load("encoding/json.star", "json")
load("cache.star", "cache")
load("secret.star", "secret")

DEFAULT_TEAM = "53"
DEFAULT_DATE = "2022-04-18"
BASE_URL = "https://soccer.sportmonks.com/api/v2.0/"
TEAMS = "teams/"

def main(config):
    api_key = secret.decrypt("AV6+...") or config.get("api_key")
    TEAM = config.get("team", DEFAULT_TEAM)
    DATE = "2022-03-19" + "/" + DEFAULT_DATE + "/"
    API = "?api_token=" + api_key
    FIXTURES = "fixtures/between/"
    PREMIER_URL = BASE_URL + FIXTURES + DATE + TEAM + API

    # cached data
    scores_cached = cache.get("match_data")
    if scores_cached != None:
        print("Hit! Displaying cached data.")
        match_data = json.decode(scores_cached)
    else:
        print("Miss! Calling API.")
        match_data = get_match_data(PREMIER_URL, API)
        # cache the data if the game is over
        if match_data["time"] == "FT":
            cache.set("match_data", str(json.encode(match_data)), ttl_seconds = 86400)
    print("MATCH DATA")
    print(match_data)

    return render.Root(
        child = 
            render.Column( 
                expanded=True,
                main_align="space_around",
                cross_align="center",
                children = [
                    render.Row(
                        expanded=True,
                        main_align="center",
                        children = [
                            render.Text(str(int(match_data["localteam_score"]))),
                            render.Text(" - "),
                            render.Text(str(int(match_data["visitorteam_score"]))),
                        ]
                    ),
                    render.Row(
                        expanded=True,
                        main_align="center",
                        cross_align="center",
                        children = [
                            render.Box(width=6, height=6, color=match_data["localteam_color"]),
                            render.Text(" "),
                            render.Text(match_data["localteam_code"]),
                            render.Text(" "),
                            render.Box(width=6, height=6, color=match_data["visitorteam_color"]),
                            render.Text(" "),
                            render.Text(match_data["visitorteam_code"]),
                        ]
                    ),
                    render.Row(
                        expanded=True,
                        main_align="center",
                        children = [
                            render.Text(str(match_data["time"]))
                        ]
                    )
                ],
            ),
        )

def get_match_data(PREMIER_URL, API):
    match_data = dict()
    rep = http.get(PREMIER_URL)

    if rep.status_code != 200:
        fail("Request failed with status ", rep.status_code)

    match = rep.json()["data"][-1]
    match_data["localteam_id"] = match["localteam_id"]
    match_data["visitorteam_id"] = match["visitorteam_id"]
    match_data["time"] = match["time"]["status"]
    match_data["localteam_score"] = match["scores"]["localteam_score"]
    match_data["visitorteam_score"] = match["scores"]["visitorteam_score"]
    match_data["localteam_color"] = match["colors"]["localteam"]["color"]
    match_data["visitorteam_color"] = match["colors"]["visitorteam"]["color"]

    # perform additional calls to find team data
    rep = http.get(BASE_URL + TEAMS + str(int(match["localteam_id"])) + API)
    if rep.status_code != 200:
        fail("Request failed with status ", rep.status_code)
    match_data["localteam_code"] = rep.json()["data"]["short_code"]
    rep = http.get(BASE_URL + TEAMS + str(int(match["visitorteam_id"])) + API)
    if rep.status_code != 200:
        fail("Request failed with status ", rep.status_code)
    match_data["visitorteam_code"] = rep.json()["data"]["short_code"]

    return match_data