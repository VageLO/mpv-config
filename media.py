import json
import requests
import subprocess
import sys
import time
import os

class Media:

    def __init__(self, config_path, fields):
        try:
            with open(config_path) as file:
                self.config = json.load(file)   
            self.fields = fields
        except json.JSONDecodeError as e:
            self.__error(e)

    def __error(self, error):
        sys.stdout.write(str({"error": error}))
        sys.exit(1)

    def __checkUrl(self):
        try:
            if requests.head(self.fields["file"]).status_code == requests.codes.ok:
                return True
            return False
        except requests.exceptions.RequestException:
            return False

    def __checkFile(self):
        if os.path.isfile(self.fields["file"]):
            return True
        return False
    
    def __ffmpeg(self, command):
        try:
            process = subprocess.Popen(command)
            process.wait()
        except Exception as e:
            self.__error(e)
    
    def ensureExtension(self):
        _, ext = os.path.splitext(self.fields['file_name'])
        if ext == '':
            self.fields['file_name'] = f'{int(time.time())}.mp4'

    def copy(self):
        fields = self.fields
        isFile = self.__checkFile()
        isUrl = self.__checkUrl()

        match(isFile, isUrl):
            case (True, False):
                ffmpeg_command = [
                    "ffmpeg",
                    "-ss", f"{fields['start_timestamp']}",
                    "-to", f"{fields['end_timestamp']}",
                    "-i", fields["file"],
                    "-map", f"0:{fields['aid']}",
                    "-map", f"0:{fields['sid']}",
                    "-map", f"0:{fields['vid']}",
                    "-c", "copy",
                    f"{self.config['COLLECTION_MEDIA_DIR']}{fields['file_name']}"
                ]

                self.__ffmpeg(ffmpeg_command)

            case (False, True):
                ffmpeg_command = [
                    "ffmpeg",
                    "-ss", f"{fields['start_timestamp']}",
                    "-to", f"{fields['end_timestamp']}",
                    "-i", fields["file"],
                    "-map", f"0:{fields['aid']}",
                    "-map", f"0:{fields['vid']}",
                    "-c", "copy",
                    f"{self.config['COLLECTION_MEDIA_DIR']}{fields['file_name']}"
                ]

                self.__ffmpeg(ffmpeg_command)

