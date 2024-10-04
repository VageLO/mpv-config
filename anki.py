import json
import requests
import sys

class AnkiConnect:

    def __init__(self, config_path):
        try:
            with open(config_path) as file:
                self.config = json.load(file)   
        except json.JSONDecodeError as e:
            self.__error(f"Config error - {e}")

    def __error(self, error):
        sys.stdout.write(str({"error": error}))
        sys.exit(1)

    def __request(self, action, params):
        return json.dumps({"action": action, "params": params, "version": 6})
    
    def __invoke(self, json):
        try: 
            response = requests.post(self.config["CONNECT_URL"], json=json)
    
            if response.status_code != 200:
                self.__error(response.status_code)

            response = response.json()
            error = response["error"]

            if error != None:
                self.__error(error)

            return response["result"]
        except requests.exceptions.ConnectionError as e:
            self.__error(e)

    def ensureDeckExist(self, deck):
        json = self.__request("changeDeck", {"cards": [], "deck": deck})
        return self.__invoke(json)

    def addNote(deck, model, fields):
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
        json = self.__request("addNote", params)
        return self.__invoke(json)

    def findNotes(self):
        params = {
            "query": f'deck:"{self.config["deck"]}"',
        }
        json = self.__request("findNotes", params)
        response = self.__invoke(json)
        
        return response

    def notesInfo(self):
        params = {
            "notes": note_ids,
        }
        json = self.__request("notesInfo", params)
        response = self.__invoke(json)
    
        notes_info = response 

        for note_info in notes_info:
            if note_info["modelName"] != self.config["note_type"]:
                continue
            fields = note_info["fields"].keys()
            return fields

    # fields_mpv = {
    #     "word": "",
    #     "sub_text": "fdjfd fjdf",
    #     "file_name": "file name"
    # }
    # anki_note_fields = getNoteFields()

    # ret = create_deck_if_not_exists(config["deck"])
    # if ret["error"] != None:
    #     return ret["error"]

    # if fields_mpv["word"] != "":
    #     fields_mpv.update(webScrapData(fields_mpv["word"]))
    # else: fields_mpv["word"] = fields_mpv["sub_text"]
    # 
    # config_fields = config["note_fields"]

    # fields = {}

    # for key, value in config_fields.items():
    #     if isinstance(value, list):
    #         for val in value:
    #             if val in fields_mpv and fields_mpv[val] != "":
    #                 if key in fields: 
    #                     fields[key] += fields_mpv[val]
    #                 else: 
    #                     fields[key] = fields_mpv[val]
    #         continue
    #     if value in fields_mpv and fields_mpv[value] != "":
    #         fields[key] = fields_mpv[value]
