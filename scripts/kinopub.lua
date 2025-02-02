package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

-- utils = require 'mp.utils'
local json = require 'dkjson'
local custom = require "custom-input"

local config = custom.loadConfig("config.json", "scripts")

if config == nil then
    print("Failed to open the JSON file.")
    return
end

PYTHON_PUB = config.PYTHON_PUB

local subtitle = ''
-- transaction id
local T = ''
local Url = ''
local Fields = {}
local Menu = "kinopub"

local function searchShow(tvshow)
    Fields = {}
    Fields["show"] = tvshow

    mp.osd_message("Searching...", 3)
    local result = custom.pythonCommand(Fields, PYTHON_PUB)
    local data = custom.check(result)

    if not data then
        return
    end

    mp.commandv("script-message-to", "osm", "clear-menu", Menu)
    for _, item in ipairs(data) do
        local command = ''
        if data["translators"] ~= nil then
            command = string.format(
                "script-message-to %s %s %s",
                Menu,
                "selected_translator",
                item["href"]
            )
        else
            command = string.format(
                "script-message-to %s %s %s",
                Menu,
                "selected_show",
                item["href"]
            )
        end
        
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            item["title"],
            command
        )
    end

    mp.commandv("script-message-to", "osm", "show-menu", Menu)
end

local function displayAudioTracks(translators)
    mp.commandv("script-message-to", "osm", "clear-menu", Menu)

    for _, item in ipairs(translators) do
        local command = string.format(
            "script-message-to %s %s %s",
            Menu,
            "selected_translator",
            item["id"]
        )
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            item["title"],
            command
        )
    end

    mp.commandv("script-message-to", "osm", "show-menu", Menu)
end

local function displaySeasons(seasons)
    mp.commandv("script-message-to", "osm", "clear-menu", Menu)

    for key, item in pairs(seasons) do
        local command = string.format(
            "script-message-to %s %s %s %s",
            Menu,
            "selected_season",
            key,
            item
        )
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            key,
            command
        )
    end

    mp.commandv("script-message-to", "osm", "show-menu", Menu)
end

local function enteredTVShow(show)
    if not show then return end
    searchShow(show)
end

mp.register_script_message("selected_show", function(url)
    Fields = {}
    Fields["url"] = url
    Url = url

    local result = custom.pythonCommand(Fields, PYTHON_PUB)
    local data = custom.check(result)

    if not data then
        return
    elseif data["translators"] ~= nil then
        displayAudioTracks(data["translators"])
        return
    end

    if data["url"] ~= nil then
        custom.loadFile(data["url"])
    end

    if data["sub"] ~= nil then
        subtitle = data["sub"]
    end
end)

mp.register_script_message("selected_translator", function(translator_id)
    Fields = {}
    Fields["url"] = Url
    Fields["translator_id"] = translator_id
    T = translator_id

    local result = custom.pythonCommand(Fields, PYTHON_PUB)
    local data = custom.check(result)

    if not data then
        return
    elseif data["seasons"] ~= nil then
        displaySeasons(data["seasons"])
        return
    end

    if data["url"] ~= nil then
        custom.loadFile(data["url"])
    end

    if data["sub"] ~= nil then
        subtitle = data["sub"]
    end
end)

mp.register_script_message("selected_season", function(season, episodes)
    mp.commandv("script-message-to", "osm", "clear-menu", Menu)

    for i = 1, tonumber(episodes) do
        local command = string.format(
            "script-message-to %s %s %s %s",
            Menu,
            "selected_episode",
            season,
            i
        )
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            i,
            command
        )
    end

    mp.commandv("script-message-to", "osm", "show-menu", Menu)
end)

mp.register_script_message("selected_episode", function(season, episode)
    Fields = {}
    Fields["translator"] = {}
    Fields["translator"]["url"] = Url
    Fields["translator"]["t"] = T
    Fields["translator"]["s"] = season
    Fields["translator"]["e"] = episode

    local result = custom.pythonCommand(Fields, PYTHON_PUB)
    local data = custom.check(result)

    if not data then
        return
    elseif data["seasons"] ~= nil then
        displaySeasons(data)
        return
    end

    if data["url"] ~= nil then
        custom.loadFile(data["url"])
    end

    if data["sub"] ~= nil then
        subtitle = data["sub"]
    end
end)
mp.register_event("file-loaded", function ()
    custom.file_loaded(subtitle)
end)

mp.add_key_binding("k", "search-kinopub", function()
    Fields = {}
    Seasons = {}
    Url = ''
    subtitle = ''
    custom.displayInput("Search on kinopub.me", enteredTVShow)
end)
