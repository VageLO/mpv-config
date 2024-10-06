import json
import sys
from anki import AnkiConnect
from media import Media

def main():
    fields_mpv = sys.argv[1]
    fields_mpv = json.loads(fields_mpv)

    with open(fields_mpv['config']) as file:
        global config 
        config = json.load(file)

    config_path = fields_mpv["config"]

    anki = AnkiConnect(config_path)
    media = Media(config_path, fields_mpv)

    media.copy()

    fields = anki.noteFields(fields_mpv) 
    deck = f'"{config["deck"]}"'
    anki.ensureDeckExist(deck)
    
    return anki.addNote(deck, config["note_type"], fields)

if __name__ == '__main__':
    result = main()

    sys.stdout.write(str(result))
    sys.exit(0)
