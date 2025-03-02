import json
import re
import sys
import time
import requests
import logging
from bs4 import BeautifulSoup
from selenium.common.exceptions import TimeoutException
from history import (
    saveSeasonsOfTranslator,
    searchPhrase,
    searchSeason,
    searchShow,
    saveShow,
    write,
    read,
)
from browser import Browser
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

def setLocalStoragePlayerSettings(driver):
    script = """
    localStorage.setItem('pljsquality', '1080p');
    """
    driver.execute_script(script)

    script = """
    localStorage.setItem('pljssubtitle', 'English');
    """
    driver.execute_script(script)

def get_source_or_seasons(translator_id, url):
    try:
        driver = startBrowser()
    except Exception as e:
        return {"error": e}

    driver.get(url)

    seasons = {}

    li = driver.find_element(By.XPATH, f"//li[@data-translator_id='{translator_id}']")
    li.click()

    WebDriverWait(driver, 10).until(
        EC.invisibility_of_element_located((By.ID, "cdnplayer-preloader"))
    )

    li_seasons = driver.find_elements(By.CLASS_NAME, 'b-simple_season__item')

    if not li_seasons:
        return captureNetwork(driver)

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
    try:
        driver = startBrowser()
    except Exception as e:
        return {"error": e}

    url = f"{translator['url']}#t:{translator['t']}-s:{translator['s']}-e:{translator['e']}"

    driver.get(url)

    # Reload page until dialog window with error is not visible
    while True:
        try:
            WebDriverWait(driver, 5).until(
                EC.presence_of_element_located(
                    (By.ID, "ps-infomessage-title"))
            )
            time.sleep(1)
            driver.execute_script("window.location.reload(true);")
        except TimeoutException:
            break

    try:
        # Wait until button with needed translator_id is active
        WebDriverWait(driver, 30).until(
            EC.presence_of_element_located(
                (By.CSS_SELECTOR, f"li[data-translator_id='{translator['t']}'].active"))
        )
        # Wait until preloader is gone
        WebDriverWait(driver, 30).until(
            EC.invisibility_of_element_located((By.ID, "cdnplayer-preloader"))
        )
    except TimeoutException:
        return {"error": "Timed out waiting for translator element or preloader"}

    time.sleep(2)

    return captureNetwork(driver)

def get(show_url):
    try:
        driver = startBrowser()
    except Exception as e:
        return {"error": e}

    driver.get(show_url)

    li_translators = driver.find_elements(By.XPATH, "//ul[@id='translators-list']/li")

    if not li_translators:
        WebDriverWait(driver, 10).until(
            EC.invisibility_of_element_located((By.ID, "cdnplayer-preloader"))
        )
        # If only video, without audio tracks and seasons 
        return captureNetwork(driver)

    translators = []

    for li in li_translators:
        id = li.get_attribute('data-translator_id')
        translator = {
            "id": id,
            "title": li.text,
        }
        translators.append(translator)

    return { "translators": translators }

def captureNetwork(driver):
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

def startBrowser():
    try:
        driver = Browser().run()
        driver.get('https://kinopub.me/')
        setLocalStoragePlayerSettings(driver)
        return driver
    except Exception as e:
        raise Exception(e)

def handle_show_search(search_key):
    try:
        return searchPhrase(search_key)
    except Exception:
        result = findShow(search_key)

        saved_history = read()
        saved_history["search"][search_key] = result
        write(saved_history)

        return result

def handle_translator_url(translator_id, url):
    try:
        return searchSeason(url, translator_id)
    except Exception:
        result = get_source_or_seasons(translator_id, url)
        try:
            saveSeasonsOfTranslator(result, url, translator_id)
        except Exception:
            pass

        return result
    
def handle_url(url):
    try:
        return searchShow(url)
    except Exception:
        result = get(url)
        saveShow(result, url)
        return result

def handle_translator(translator):
    return get_episode_url(translator)

def main():
    try:
        args = sys.argv[1]
        args = json.loads(args)
    except Exception as e:
        return {"error": f'Error {e} {sys.argv}'}

    if 'show' in args:
        search_key = args["show"].strip().lower()
        return handle_show_search(search_key) 

    if 'translator_id' in args and 'url' in args:
        return handle_translator_url(args["translator_id"], args["url"])
    elif 'url' in args:
        return handle_url(args["url"])
    elif 'translator' in args:
        return handle_translator(args["translator"])

if __name__ == "__main__":
    #logging.basicConfig(level=logging.DEBUG)
    result = main()
    result = json.dumps(result)

    sys.stdout.write(str(result))
    sys.exit(0)
