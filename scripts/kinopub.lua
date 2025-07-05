package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local custom = require "custom-input"

local config = custom.loadConfig("config.json", "scripts")

if config == nil then
    print("Failed to open the JSON file.")
    return
end

UV_PUB_DIR = config.UV_PUB
UV_PUB = "kinopub.py"

local subtitle = ''
-- transaction id
local T = ''
local Url = ''
local Menu = "kinopub"

local function searchShow(tvshow)
    mp.osd_message("Searching...", 3)
    local command = "show -t ".."'"..tvshow.."'"
    local result = custom.pythonCommand(
        command,
        UV_PUB_DIR,
        UV_PUB
    )
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
            "script-message-to %s %s %s %s",
            Menu,
            "selected_translator",
            item["id"],
            item["href"]
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

    for _, item in pairs(seasons) do
        local command = string.format(
            "script-message-to %s %s %s %s",
            Menu,
            "selected_season",
            item["key"],
            item["value"]
        )
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            item["key"],
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
    Url = url
    local command = "translator -u " .. url

    local result = custom.pythonCommand(
        command,
        UV_PUB_DIR,
        UV_PUB
    )
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

mp.register_script_message("selected_translator", function(ti, thref)
    Url = thref
    local command = "translator -u " .. Url .. " -ti " .. ti
    T = ti

    local result = custom.pythonCommand(
        command,
        UV_PUB_DIR,
        UV_PUB)
    local data = custom.check(result)

    if not data then
        return
    elseif data["seasons"] ~= nil then
        local sort = custom.sortTableByKey(data["seasons"])
        displaySeasons(sort)
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
    local command = "translator -u " .. Url
    command = command .. " -ti " .. T
    command = command .. " -s " .. season
    command = command .. " -e " .. episode

    local result = custom.pythonCommand(
        command,
        UV_PUB_DIR,
        UV_PUB)

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
    Seasons = {}
    Url = ''
    subtitle = ''
    custom.displayInput("Search on kinopub.me", enteredTVShow)
end)
