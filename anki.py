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
        return {"action": action, "params": params, "version": 6}
    
    def __invoke(self, json):
        try: 
            response = requests.post(self.config["CONNECT_URL"], json=json)
    
            if response.status_code != 200:
                self.__error(response.status_code)

            response = response.json()
            error = response["error"]

            if error != None:
                self.__error(error)

            return response
        except requests.exceptions.ConnectionError as e:
            self.__error(e)

    def ensureDeckExist(self, deck):
        json = self.__request("changeDeck", {"cards": [], "deck": deck})
        return self.__invoke(json)

    def addNote(self, deck, model, fields):
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
        return self.__invoke(json)

    def notesInfo(self, note_ids):
        params = {
            "notes": note_ids,
        }
        json = self.__request("notesInfo", params)
        response = self.__invoke(json)
    
        notes_info = response["result"]

        for note_info in notes_info:
            if note_info["modelName"] != self.config["note_type"]:
                continue
            fields = note_info["fields"].keys()
            return fields

    def noteFields(self, fields_mpv):
        config_fields = self.config["note_fields"]

        fields = {}

        for key, value in config_fields.items():
            if isinstance(value, list):
                for val in value:
                    if val in fields_mpv and fields_mpv[val] != "":
                        if key in fields: 
                            fields[key] += fields_mpv[val]
                        else: 
                            fields[key] = fields_mpv[val]
                continue
            if value in fields_mpv and fields_mpv[value] != "":
                fields[key] = fields_mpv[value]

        return fields
