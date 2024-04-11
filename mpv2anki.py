import json
import requests
import sys
import configparser
import subprocess
import os

config = configparser.ConfigParser()
config.read(os.getcwd() + '/config.ini')

def send_to_anki(method, params):
    try: 
        r = requests.post("http://127.0.0.1:8765", data=json.dumps({"action": method, "version": 5, "params": params}))
        return json.loads(r.text)
    except requests.exceptions.ConnectionError:
        return False

def create_deck_if_not_exists(deck):
    ret = send_to_anki("changeDeck", {"cards": [], "deck": deck })
    return ret

def add_anki_card(deck, model, fields):
    params = {
        "note": {
            "deckName": deck,
            "modelName": model,
            "fields": json.loads(fields),
            "tags": [
				"todo"
			],
        }
    }
    return send_to_anki("addNote", params)

def ffmpeg_call(fields):

    ffmpeg_command = [
        "ffmpeg",
        "-i", fields["file"],
        "-ss", str(fields["start_timestamp"]),
        "-t", str(fields["end_timestamp"] - fields["start_timestamp"]),
        "-map", f"0:aid={fields["aid"]}",
        "-map", f"0:sid={fields["sid"]}",
        "-c", "copy",
        fields["file_name"]
    ]

    # process = subprocess.run(ffmpeg_command)
    # process.wait()

def main():
    fields = sys.argv[1]
    fields = json.loads(fields)
    ffmpeg_call(fields)
    # print(file, fields)
    # ret = create_deck_if_not_exists(deck)

    if ret == False:
        return False
    else:
        return False

if __name__ == '__main__':
    ret = main()

    if ret != False and ret["result"] != None:
        sys.exit(0)
    else:
        sys.exit(1)
