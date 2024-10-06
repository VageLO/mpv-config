package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

utils = require 'mp.utils'
local json = require 'dkjson'
local input = require "user-input-module"

local scripts_dir = mp.find_config_file("scripts")
local file = io.open(scripts_dir .. "/config.json", "r")

if file then
    local content = file:read("*a")
    file:close()

    -- Parse JSON into a Lua table
    config = json.decode(content)
else
    print("Failed to open the JSON file.")
end

PYTHON_REZKA = config.PYTHON_REZKA

local fields = {}
local subs = nil
local showData = nil
local menu = "rezka"

local function displayInput(message, func)
    mp.osd_message("🕳 Enter " .. message)

    input.get_user_input(func, {
        request_text = "❤ " .. message .. ":",
        replace = true
    }, "replace")
end

local function pythonCommand(args)
    args = json.encode(args)
    local handle = io.popen([[python]] .. " " .. PYTHON_REZKA .. " '" .. args .. "'")

    local result = handle:read("*a")
    handle:close()

    --local jsonStr = result:gsub("'", '"')
    --local data, pos, err = json.decode(jsonStr, 1, nil)

    --if err then
    --    print("Error decoding JSON:", err)
    --end

    return result
end

function getData(tvshow)
    fields = {}
    fields["show"] = tvshow

    mp.osd_message("Searching...", 3)
    local result = pythonCommand(fields)

    local jsonStr = result:gsub("'", '"')
    local data, pos, err = json.decode(jsonStr, 1, nil)

    if err then
        mp.osd_message("Error decoding JSON: " .. err, 5)
        return
    end

    if data ~= nil and data["error"] then
        mp.osd_message(data["error"], 5)
        return
    elseif data == nil then
        mp.osd_message("nil value", 5)
        return
    end

    mp.commandv("script-message-to", "osm", "clear-menu", menu)
    for _, item in ipairs(data) do
        local command = "script-message-to " .. "rezka " .. "parse " .. item["href"]
        mp.commandv("script-message-to", "osm", "add-to-menu", menu, item["title"], command)
    end

    mp.commandv("script-message-to", "osm", "show-menu", menu)
end

local function enteredTVShow(show, err, flag)
    if not show then return end
    getData(show)
end

local function isArray(t)
    if type(t) ~= "table" then
        return false -- Not a table
    end

    local count = 0
    for _, _ in ipairs(t) do
        count = count + 1
    end

    return count > 0
end

local function loadVideo(url)
    if url == nil then
        mp.osd_message("loadVideo: url is nil", 5)
    end

    mp.msg.info("Loading URL: " .. url)
    mp.osd_message("Video is loading. Wait a minute!", 5)

    mp.commandv("loadfile", url)
    mp.command("set pause no")
end

local function loadSubtitles(url, title)
    mp.commandv("sub-add", url, "auto", title)
end

mp.register_event("file-loaded", function()
    local filename = mp.get_property("filename")
    if filename then
        if subs == nil then
            return
        end
        mp.osd_message(filename .. " loaded", 3)
        for _, sub in ipairs(subs) do
            print(sub["name"] .. " loaded")
            loadSubtitles(sub["url"], sub["name"])
        end
    end
end)

local function showSeasons()
    if showData == nil then
        mp.osd_message("showSeasons: showData is nil", 5)
        return
    end

    mp.commandv("script-message-to", "osm", "clear-menu", menu)
    for _, item in ipairs(showData) do
        local title = "Season " .. item.season
        local command = "script-message-to " .. "rezka " .. "show-episodes " .. item.season
        mp.commandv("script-message-to", "osm", "add-to-menu", menu, title, command)
    end
    mp.commandv("script-message-to", "osm", "show-menu", menu)
end

local function findSeason(season)
    if showData == nil then
        mp.osd_message("findSeason: showData is nil", 5)
        return
    end
    for _, item in ipairs(showData) do
        if item.season == tonumber(season) then
            return item
        end
    end
    return nil
end

local function findEpisode(season, episodeID)
    local seasonObj = findSeason(season)
    if seasonObj == nil then
        mp.osd_message("findEpisode: seasonObj is nil", 5)
        return
    end
    for _, item in ipairs(seasonObj.episodes) do
        if item.id == tonumber(episodeID) then
            return item
        end
    end
    return nil
end

mp.register_script_message("load-episode", function(season, episodeID)
    local episodeObj = findEpisode(season, episodeID)
    if episodeObj == nil then
        mp.osd_message("load-episode: episodeObj is nil", 5)
        return
    end
    loadVideo(episodeObj.hls)
    if episodeObj.cc ~= nil and #episodeObj.cc > 0 then
        subs = episodeObj.cc
    end
end)

mp.register_script_message("show-episodes", function(season)
    local seasonObj = findSeason(season)
    if seasonObj == nil then
        mp.osd_message("show-episodes: seasonObj is nil", 5)
        return
    end

    mp.commandv("script-message-to", "osm", "clear-menu", menu)
    for _, episode in ipairs(seasonObj.episodes) do
        local command = "script-message-to " .. "rezka " .. "load-episode " .. seasonObj.season
            .. " " .. episode.id
        local title = episode.episode .. ". " .. episode.title
        mp.commandv("script-message-to", "osm", "add-to-menu", menu, title, command)
    end
    mp.commandv("script-message-to", "osm", "show-menu", menu)
end)

local function isMovie(data)
    loadVideo(data["hls"])
    if data["cc"] ~= nil and #data["cc"] > 0 then
        subs = data["cc"]
    end
end

mp.add_key_binding("p", "select-tvshow", function()
    subs = nil
    showData = nil
    fields = {}
    displayInput("TV Show on Rezka.biz", enteredTVShow)
end)

mp.register_script_message("parse", function(url)
    fields = {}
    fields["url"] = url

    local data = pythonCommand(fields)

    if data ~= nil and data["error"] then
        mp.osd_message(data["error"], 5)
        return
    elseif data == nil then
        mp.osd_message("parse: data is nil", 5)
        return
    end

    local newData, pos, err = json.decode(data, 1, nil)
    if err then
        mp.osd_message(err)
        return
    end

    if isArray(newData) then
        showData = newData
        showSeasons()
    else
        isMovie(newData)
    end
end)
