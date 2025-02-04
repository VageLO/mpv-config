import json
import os
from typing import Any

def read() -> Any:
    path = os.path.join(os.path.expanduser('~'), '.config', 'kinopub-history.json')
    if not os.path.exists(path):
        write({"search": {}, "shows": []})

    with open(path, 'r') as infile:
        try:
            return json.load(infile)
        except json.JSONDecodeError as e:
            raise Exception(e)

def write(data):
    path = os.path.join(os.path.expanduser('~'), '.config', 'kinopub-history.json')
    with open(path, 'w') as file:
        json.dump(data, file, indent=4)

def searchPhrase(phrase):

    try:
        data = read()
    except Exception as e:
        raise Exception(e)

    if phrase in data["search"]:
        return data["search"][phrase]
    else:
        raise Exception("No item found")

def searchShow(href):
    try:
        existing_data = read()
    except Exception as e:
        raise Exception(e)

    for show in existing_data["shows"]:
        if show["href"] == href:
            if "translators" in show:
                return {"translators": show["translators"]}
            elif "url" in show:
                return {"url": show["url"], "sub": show["sub"]} 

    raise Exception("No item found")

def searchSeason(href):
    try:
        existing_data = read()
    except Exception as e:
        raise Exception(e)

    for show in existing_data["shows"]:
        if show["href"] == href:
            if "translators" in show:
                return {"translators": show["translators"]}
            elif "url" in show:
                return {"url": show["url"], "sub": show["sub"]} 

    raise Exception("No item found")
def saveShow(data, href):
    try:
        existing_data = read()
    except Exception as e:
        raise Exception(e)

    exist = None
    for index, show in enumerate(existing_data["shows"]):
        if show["href"] == href:
            exist = index

    show = {
        "href": href,
    }

    if "url" in data:
        show["url"] = data["url"]
    if "sub" in data:
        show["sub"] = data["sub"]
    if "translators" in data:
        show["translators"] = data["translators"]
    if "seasons" in data:
        show["seasons"] = data["seasons"]

    if exist is not None:
        existing_data["shows"][exist].update(show)
    else:
        existing_data["shows"].append(show)

    write(existing_data)

