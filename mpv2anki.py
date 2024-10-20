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

    media.ensureExtension()

    anki_fields = fields_mpv.copy()
    anki_fields['file_name'] = f'[sound:{anki_fields["file_name"]}]'
    anki_fields['sub_text'] = f'<ul><li>{anki_fields["sub_text"]}</li></ul>'

    anki_fields = anki.noteFields(anki_fields) 
    deck = f'"{config["deck"]}"'
    anki.ensureDeckExist(deck)
    
    result = anki.addNote(deck, config["note_type"], anki_fields)
    if result['error'] is not None:
        return result

    anki.suspendCard(result['result'])
    media.copy()

if __name__ == '__main__':
    result = main()

    sys.stdout.write(str(result))
    sys.exit(0)
