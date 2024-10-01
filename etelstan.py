import json
import sys
import re
import logging
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.action_chains import ActionChains
#from selenium.webdriver.chrome.service import Service
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait as wait
from selenium.common.exceptions import WebDriverException

class Browser:

    logging.basicConfig(level=logging.INFO, filename="log.log",filemode="w", format="%(asctime)s %(levelname)s %(message)s")
    userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36'

    def __init__(self):
        try:
            #service = Service('D:\\test-obsidian\mpv-config\chromedriver_win32\chromedriver.exe')
            options = webdriver.ChromeOptions()

            options.add_argument("--headless")
            options.add_argument("--window-size=1920,1080")
            options.add_argument("--auto-open-devtools-for-tabs")
            options.add_argument("--disable-features=IsolateOrigins,site-per-process")
            options.add_argument("--disable-site-isolation-trials")
            options.add_argument(f"user-agent={self.userAgent}")
            #options.add_experimental_option("detach", True)

            options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})
        
            #driver = webdriver.Chrome(service=service, options=options)
            driver = webdriver.Chrome(options=options)
        
            driver.execute_cdp_cmd('Network.enable', {})
            driver.execute_cdp_cmd('Debugger.enable', {})
            self.driver = driver
        
        except WebDriverException as e:
            sys.stdout.write(
                str({"error": f"ChromeDriver is not installed. \n{e}"}))
            sys.exit(1)

    def captureNetwork(self, fileId):
        logs = self.driver.get_log("performance")
        
        for log in logs:
            message = json.loads(log["message"])["message"]
            if "Network.responseReceived" in message["method"]:
                params = message.get("params")
                if params:
                    response = params.get("response")
                    request = params.get("request")
                    if response:
                        if response and fileId in response["url"]:
                            logging.info(response["url"])
                    #elif request:
                    #    logging.info(request)

    def get(self, url):
        self.driver.get(url)
        
        frame = self.driver.find_element(By.TAG_NAME, "iframe")

        actions = ActionChains(self.driver)
        actions.move_to_element(frame).perform()

        wait(self.driver, 5).until(EC.frame_to_be_available_and_switch_to_it((By.TAG_NAME, "iframe")))
        list_item = wait(self.driver, 5).until(EC.element_to_be_clickable((By.CLASS_NAME, "list__item")))

        button_list = wait(self.driver, 5).until(EC.presence_of_all_elements_located((By.CLASS_NAME, "list__drop-item")))
        for button in button_list:
            fileId = button.get_attribute("data-id-file-s")
            if fileId == "":
                fileId = button.get_attribute("data-id-file")

            # drop down button
            wait(self.driver, 5).until(EC.element_to_be_clickable(list_item)).click()

            wait(self.driver, 5).until(EC.element_to_be_clickable(button)).click()

            # setting button
            settings = wait(self.driver, 5).until(EC.visibility_of_element_located((By.XPATH, '/html/body/div[2]/pjsdiv/pjsdiv[20]/pjsdiv[3]')))
            settings.click()

            # Subtitles
            sub_button = self.driver.find_element(By.CSS_SELECTOR, 'pjsdiv[fid="3"]')
            if sub_button.is_displayed():
                sub_button.click()
                subs = self.driver.find_elements(By.CSS_SELECTOR, "[f2id]")

                for sub in subs:
                    if int(sub.get_attribute("f2id")) > 2: 
                        # TODO:
                        wait(self.driver, 5).until(EC.element_to_be_clickable(settings)).click()
                        sub_button.click()
                        sub.click()
                        pass

                    sub.click()

            self.captureNetwork(fileId)

def main():
    browser = Browser()
    browser.get("https://rezka.biz/filmy/99515-voron.html")

if __name__ == "__main__":
    main()
