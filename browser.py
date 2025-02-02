from selenium import webdriver
from selenium.common.exceptions import WebDriverException

class Browser:
    def run(self):
        try:
            options = webdriver.ChromeOptions()
            options.add_argument("--headless")
            options.add_argument("--window-size=1920,1080")
            options.add_argument(
                "user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")
            options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})
            #options.add_experimental_option('detach', True)
        
            driver = webdriver.Chrome(options=options)
        
            driver.execute_cdp_cmd('Network.enable', {})
            driver.execute_cdp_cmd('Debugger.enable', {})
            return driver
        
        except WebDriverException as e:
            raise Exception(str({"error": f"ChromeDriver is not installed. \n{e}"}))

    def remote(self, session_id, executer_url):
        options = webdriver.ChromeOptions()
        options.add_argument("--headless")
        options.add_argument("--window-size=1920,1080")
        options.add_argument(
            "user-agent=Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36")
        options.set_capability('goog:loggingPrefs', {'performance': 'ALL'})
        #options.add_experimental_option('detach', True)

        
        driver = webdriver.Remote(command_executor=executer_url, options=options)
        driver.session_id = session_id
        print(f'Using session: {session_id} on {executer_url}')
        return driver
