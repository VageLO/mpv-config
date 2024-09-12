import json
import sys
import re
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

options = webdriver.ChromeOptions()
options.add_argument("--headless")
options.add_argument("--window-size=1920,1080")
options.add_argument(
    "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.4577.63 Safari/537.36")
options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})

driver = webdriver.Chrome(options=options)

driver.execute_cdp_cmd('Network.enable', {})
driver.execute_cdp_cmd('Debugger.enable', {})


def get(url):

    driver.get(url)

    li_list = driver.find_elements(By.TAG_NAME, 'li')
    for li in li_list:
        data_src = li.get_attribute('data-src')
        if data_src and re.search(r'https://api\.ninsel\.ws', data_src):
            driver.get(data_src)
            return captureNetwork(data_src)

    return {"error": "Error cant find right player"}


def captureNetwork(url):
    logs = driver.get_log("performance")

    for log in logs:
        message = log["message"]
        if "Network.responseReceived" in message:
            params = json.loads(message)["message"].get("params")
            if params:
                response = params.get("response")
                if response:
                    if response and url in response["url"]:
                        try:
                            body = driver.execute_cdp_cmd('Network.getResponseBody', {
                                'requestId': params["requestId"]})
                            return parseToJson(f'{body}')

                        except Exception as e:
                            return {"error": f'Error {e}'}


def ensureDoubleQuotes(string):
    pattern = r'(?<!["\w])(\w+)(?=\s*:)'
    quoted_string = re.sub(pattern, r'"\1"', string)

    return quoted_string


def parseToJson(body):

    # source = re.search(r'source:\s({.*}\]\\n\\t\\t\\t})', body)
    source = re.search(r'source:\s({.*\]\\n\\t\\t\\t})', body)
    # playlist = re.search(r'playlist:\s({.*}]\\n\\t\\t\\t})', body)
    seasons = re.search(r'seasons:(\[{.*}\])', body)

    if source is None:
        json_part = seasons

    if seasons is None:
        json_part = source

    if json_part:
        json_string = json_part.group(1)

        json_string = json_string.replace(
            '\\n', '').replace('\\t', '').strip()

        json_string = json_string.replace("'", '"')
        json_string = ensureDoubleQuotes(json_string)
        data = json.loads(json_string)
        if seasons is not None:
            data = sorted(data, key=lambda x: x['season'])

        try:
            global parsed_json
            parsed_json = json.dumps(data, indent=4)

        except json.JSONDecodeError as e:
            return {"error" f"JSON decoding error: {e}"}
    else:
        return {"error": "No JSON part found"}

    return parsed_json


def findShow(show):
    url = "https://rezka.biz/"
    driver.get(url)

    inputs = driver.find_elements(By.TAG_NAME, 'input')
    for input in inputs:
        holder = input.get_attribute('placeholder')
        if holder and holder == "Поиск фильмов и сериалов":
            input.send_keys(show)

    try:
        element = WebDriverWait(driver, 2).until(
            EC.visibility_of_element_located(
                (By.CLASS_NAME, "lSerachResults"))
        )
    except Exception:
        return {"error": "Error cant find any show"}

    items = element.find_elements(By.CLASS_NAME, "sliderItem")
    results = []

    if items:
        for item in items:
            span = item.find_element(By.CLASS_NAME, 'sliderMisc')
            a = item.find_element(By.TAG_NAME, 'a')
            href = a.get_attribute('href')
            title = a.get_attribute('title')
            results.append({
                'href': href,
                'title': f'{title} {span.text}',
            })

    return results


def main():
    try:
        args = sys.argv[1]
        args = json.loads(args)
    except Exception as e:
        return {"error": f'Error {e} {args} {sys.argv}'}
    except json.JSONDecodeError:
        return {"error": f'Error json decode {args}'}

    result = []
    if 'show' in args:
        result = findShow(args["show"])

    if 'url' in args:
        result = get(args["url"])

    driver.quit()

    return result


if __name__ == "__main__":
    result = main()

    sys.stdout.write(str(result))
    sys.exit(0)
