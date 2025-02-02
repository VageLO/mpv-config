import json
import re
import sys
import time
import requests
from bs4 import BeautifulSoup
from browser import Browser
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

def setLocalStoragePlayerSettings():
    script = """
    localStorage.setItem('pljsquality', '1080p');
    """
    driver.execute_script(script)

    script = """
    localStorage.setItem('pljssubtitle', 'English');
    """
    driver.execute_script(script)

def get_source_or_seasons(translator_id, url):
    driver.get(url)

    seasons = {}
    li = driver.find_element(By.XPATH, f"//li[@data-translator_id='{translator_id}']")

    li.click()
    time.sleep(2)

    li_seasons = driver.find_elements(By.CLASS_NAME, 'b-simple_season__item')

    if not li_seasons:
        return captureNetwork()

    seasons = {}

    for li in li_seasons:
        tab_id = li.get_attribute('data-tab_id')
        if tab_id:
            seasons[tab_id] = 0

    for id in seasons.keys():
        li_episodes = driver.find_elements(By.XPATH, f"//li[@data-season_id='{id}']")
        seasons[id] = len(li_episodes)

    return { "seasons": seasons }

def get_episode_url(translator):
    url = f"{translator['url']}#t:{translator['t']}-s:{translator['s']}-e:{translator['e']}"

    driver.get(url)

    WebDriverWait(driver, 10).until(
        EC.presence_of_element_located(
            (By.CSS_SELECTOR, f"li[data-translator_id='{translator['t']}'].active"))
    )

    return captureNetwork()

def get(show_url):

    driver.get(show_url)

    li_translators = driver.find_elements(By.XPATH, "//ul[@id='translators-list']/li")

    if not li_translators:
        # If only video, without audio tracks and seasons 
        return captureNetwork()

    translators = []

    for li in li_translators:
        id = li.get_attribute('data-translator_id')
        translator = {
            "id": id,
            "title": li.text,
        }
        translators.append(translator)

    return { "translators": translators }

def captureNetwork():
    logs = driver.get_log("performance")

    result = {
        "url": '',
        "sub": ''
    }

    for log in reversed(logs):
        message = log["message"]
        if "Network.responseReceived" in message:
            params = json.loads(message)["message"].get("params")
            if params:
                response = params.get("response")
                if response:
                    if not result["url"] and response["url"].endswith('.m3u8'):
                        match = re.search(r'(.+?\.mp4)', response["url"])
                        if match:
                            result["url"] = match.group(1)
                    if not result["sub"] and response["url"].endswith('.vtt'):
                        result["sub"] = response["url"]
    return result

def scrapAllShows(url):
    try:
        driver = Browser().run()
    except Exception as e:
        return e

    pages = []
    results = []
    is_navigation = False

    pages.append(url)

    for page in pages:
        driver.get(page)

        WebDriverWait(driver, 5).until(
            EC.presence_of_element_located((By.CLASS_NAME, "b-content__inline_items"))
        )

        html = driver.page_source
        soup = BeautifulSoup(html, 'html.parser')

        if not is_navigation:
            links_without_span = [a for a in soup.select('div.b-navigation a') if not a.find('span', recursive=False)]

            is_navigation = True

            for link in links_without_span:
                pages.append(link['href'])

        soup = BeautifulSoup(html, 'html.parser')
        items = soup.find_all(class_='b-content__inline_item-link')

        for item in items:
            a = item.find('a')
            if a:
                href = a.get('href')
                title = item.text.strip()
                results.append({
                    'href': href,
                    'title': title,
                })

    return results

def findShow(show):

    url = f"https://kinopub.me/engine/ajax/search.php?q={show.replace(' ', '%20')}"
    response = requests.get(url)

    if response.status_code != 200:
        return {"error": "Can't find any show"}


    soup = BeautifulSoup(response.text, 'html.parser')

    all = soup.find(class_="b-search__live_all")

    # If to many common items
    if all:
        return scrapAllShows(all.get('href').replace(' ', '%20'))

    items = soup.find_all('li')

    if not items:
        return {"error": "Can't find any show"}

    results = []

    for item in items:
        rating = item.find(class_='rating')
        a = item.find('a')

        if a and rating:
            href = a.get('href')
            title = a.text.replace(rating.text, '').strip()
            results.append({
                'href': href,
                'title': title,
            }) 

    return results

def main():
    try:
        args = sys.argv[1]
        args = json.loads(args)
    except Exception as e:
        return {"error": f'Error {e} {args} {sys.argv}'}

    #except json.JSONDecodeError:
    #    return {"error": f'Error json decode {args}'}

    #args = {
    #    # session
    #    #"session": {
    #    #    'id': '8062b72ef3bc3712633179323c0836c8',
    #    #    'url': 'http://localhost:43793'
    #    #},
    #    # search video
    #    #"show": "silo",
    #    
    #    # with translators
    #    "url": "https://kinopub.me/films/detective/1194-sem-1995.html",

    #    # without translators
    #    #"url": "https://kinopub.me/films/western/76932-lyubiteli-nepriyatnostey-1994.html",

    #    # get source or seasons
    #    #"url": "https://kinopub.me/series/drama/55680-ukrytie-2023.html",
    #    #"url": "https://kinopub.me/series/comedy/76717-videozhest-2025.html",
    #    #"url": "https://kinopub.me/films/detective/1194-sem-1995.html",
    #    #"translator_id": '238',

    #    # selected episode
    #    #"translator": {
    #    #    "url": "https://kinopub.me/series/drama/55680-ukrytie-2023.html",
    #    #    "t": "238",
    #    #    "s": "1",
    #    #    "e": "2"
    #    #}
    #}

    global driver
    result = {}

    if 'show' in args:
        result = findShow(args["show"])
        return result

    try:
        #if 'session' in args:
        #    browser = Browser()
        #    driver = browser.remote(args['session']['id'], args['session']['url'])
        #else:
            driver = Browser().run()
            driver.get('https://kinopub.me/')
            setLocalStoragePlayerSettings()
    except Exception as e:
        return e

    if 'translator_id' in args and 'url' in args:
        result = get_source_or_seasons(args["translator_id"], args["url"])

    elif 'url' in args:
        result = get(args["url"])

    elif 'translator' in args:
        result = get_episode_url(args["translator"])

    #if "url" not in result:
    #    result["session"] = {
    #        'id': driver.session_id,
    #        'url': driver.service.service_url
    #    }
    driver.close()

    return result


if __name__ == "__main__":
    result = main()
    result = json.dumps(result)

    sys.stdout.write(str(result))
    sys.exit(0)
