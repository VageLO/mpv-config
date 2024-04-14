import json
import requests
import sys
import subprocess
from bs4 import BeautifulSoup

with open('C:\\Users\\maksg\\AppData\\Roaming\\mpv\\scripts\\config.json') as file:
    global config 
    config = json.load(file)

def send_to_anki(method, params):
    try: 
        res = requests.post(config["CONNECT_URL"], json={"action": method, "version": 6, "params": params})

        if res.status_code != 200:
            return {"error": res.status_code}
        res = res.json()

        if res["error"] != None:
            return {"error": res["error"]}
        return res
    except requests.exceptions.ConnectionError:
        return {"error": False}

def create_deck_if_not_exists(deck):
    ret = send_to_anki("changeDeck", {"cards": [], "deck": deck})
    return ret

def add_anki_card(deck, model, fields):
    params = {
        "note": {
            "deckName": deck,
            "modelName": model,
            "fields": fields,
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
        "-ss", f"{fields["start_timestamp"]}",
        "-to", f"{fields["end_timestamp"]}",
        "-map", f"0:{fields["aid"]}",
        "-map", f"0:{fields["sid"]}",
        "-map", f"0:{fields["vid"]}",
        "-c", "copy",
        f"{config["COLLECTION_MEDIA_DIR"]}{fields["file_name"]}"
    ]

    process = subprocess.Popen(ffmpeg_command)
    process.wait()

def getNoteFields():
    anki_connect_url = config["CONNECT_URL"]

    payload = {
        "action": "findNotes",
        "version": 6,
        "params": {
            "query": f'deck:"{config["deck"]}"',  # Modify this to your desired deck name or query
        }
    }
    res = requests.post(anki_connect_url, json.dumps(payload))
    if res.status_code != 200:
        return {"error": False}
    
    note_ids = res.json()["result"]
    payload = {
        "action": "notesInfo",
        "version": 6,
        "params": {
            "notes": note_ids,
        }
    }
    
    res = requests.post(anki_connect_url, json.dumps(payload))
    
    if res.status_code != 200:
        return {"error": False}
    res = res.json()
    if res["error"] != None:
        return {"error": res["error"]}
    
    notes_info = res["result"]

    for note_info in notes_info:
        if note_info["modelName"] != config["note_type"]:
            continue
        fields = note_info["fields"].keys()
        return fields

def webScrapData(quote_word):
    result = {
        'meaning': '',
        'example': '',
        'word_form': '',
        'image': '',
        'transcription': '',
    }
    
    url = f'https://wooordhunt.ru/word/{quote_word}'
    wordhunt_html = requests.get(url)
    
    if wordhunt_html.status_code == 200:
        soup = BeautifulSoup(wordhunt_html.text, 'html.parser')
        
        meaning = soup.find('div', class_='t_inline_en')
        if(meaning): result['meaning'] = meaning.get_text()

        examples = soup.find_all('p', class_='ex_o')
        if examples:
            for example in examples[0:3]:
                result['example'] += f'<li>{example.get_text().strip()}</li>'

        word_forms = soup.find_all('div', class_='word_form_block')
        if word_forms:
            for form in word_forms:
                result['word_form'] += f"{form.get_text()}"

    url = f'https://dictionary.skyeng.ru/api/v2/search-word-exact?images=400x300&word={quote_word}'
    res = requests.get(url)
    
    if res.status_code == 200:
        res = res.json()
        array = res["meanings"]
            
        for image in array:
            resolution = list(image["images"].keys())[0]
            result['transcription'] = image["transcription"]
            result['image'] += f'<img width="{400} height="{300} src="{image["images"][resolution]["url"]}"/>'

    return result

def main():
    fields_mpv = sys.argv[1]
    fields_mpv = json.loads(fields_mpv)
    ffmpeg_call(fields_mpv)
    # anki_note_fields = getNoteFields()

    # ret = create_deck_if_not_exists(config["deck"])
    # if ret["error"] != None:
    #     return ret["error"]

    if(fields_mpv["word"] != ""):
        data = webScrapData(fields_mpv["word"])

        fields = {
            "Word": fields_mpv["word"],
            "Meaning": data["meaning"],
            "Examples": f"<ul>{data["example"]}<li>{fields_mpv["sub_text"]}</li></ul>",
            "WordForm": data["word_form"],
            "Video": fields_mpv["file_name"],
            "Image": data["image"],
            "Transcription": data["transcription"],
        }
    else:
        fields = {
            "Word": fields_mpv["sub_text"],
            "Examples": f"<ul><li>{fields_mpv["sub_text"]}</li></ul>",
            "Video": fields_mpv["file_name"],
        }
    
    return add_anki_card(f'"{config["deck"]}"', config["note_type"], fields)

if __name__ == '__main__':
    ret = main()

    if ret["error"] == None and ret["result"] != None:
        sys.exit(0)
    else:
        sys.stderr(str(ret))
        sys.stdout(str(ret))
        sys.exit(1)
