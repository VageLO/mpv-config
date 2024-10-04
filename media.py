import json
import requests
import sys

class Media:

    def __init__(self, config_path):
        try:
            with open(config_path) as file:
                self.config = json.load(file)   
        except json.JSONDecodeError as e:
            self.__error(f"Config error - {e}")

    def __error(self, error):
        sys.stdout.write(str({"error": error}))
        sys.exit(1)

    def ffmpeg(self, fields):
        pass
