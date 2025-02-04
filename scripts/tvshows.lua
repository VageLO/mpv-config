package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

utils = require 'mp.utils'
local json = require 'dkjson'
local input = require "user-input-module"
local custom = require "custom-input"

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

PYTHON_TVSHOWS = config.PYTHON_TVSHOWS

local fields = {}

local function displayInput(message, func)
    mp.osd_message("🕳 Enter " .. message)

    input.get_user_input(func, {
        request_text = "❤ " .. message .. ":",
        replace = true
    }, "replace")
end

local function pythonCommand(args)
    args = json.encode(args)
    local handle, err = io.popen([[python]] .. " " .. PYTHON_TVSHOWS .. " '" .. args .. "'")

    local result = handle:read("*a")
    handle:close()
    print(json.encode(result))

    local jsonStr = result:gsub("'", '"')
    local data, pos, err = json.decode(jsonStr, 1, nil)

    if err then
        print("Error decoding JSON:", err)
    end

    return data
end

local function openEpisode(episode)
    local num = tonumber(episode)
    if num == nil then
        mp.osd_message("Conversion faild", 1)
        return
    end

    if num < 1 or num > fields["episodes"] then
        mp.osd_message("Enter number between 1 and " .. fields["episodes"], 1)
        return
    end

    episode = num

    if episode < 10 then
        episode = "0" .. episode
    end

    mp.commandv("loadfile", fields["url"] .. episode .. ".mp4")
    mp.command("set pause no")
end

mp.register_event("file-loaded", function ()
    local filename = mp.get_property('filename')
    local parts = custom.split(filename, "%.")
    local sub = fields["sub"] .. parts[1] .. ".vtt"
    custom.file_loaded(sub)
end)

local function enteredEpisodeNumber(episode, err, flag)
    if not episode then return end
    openEpisode(episode)
end


local function getEpisodes(season)
    local num = tonumber(season)
    if num == nil then
        mp.osd_message("Conversion faild", 1)
        return
    end

    if num < 1 or num > fields["seasons"] then
        mp.osd_message("Enter number between 1 and " .. fields["seasons"], 1)
        return
    end

    season = num

    local args = {}
    args["showID"] = fields["showID"]
    args["selectedSeason"] = season
    args["part"] = fields["part"]
    fields = {}

    local data = pythonCommand(args)

    fields["episodes"] = data["episodes"]
    fields["url"] = data["url"]
    fields["sub"] = data["sub"]

    displayInput("Episode " .. "(1 - " .. fields["episodes"] .. ")", enteredEpisodeNumber)
end

local function enteredSeasonNumber(season, err, flag)
    if not season then return end
    getEpisodes(season)
end


function getSeasons(tvshow)
    fields = {}
    fields["show"] = tvshow

    local data = pythonCommand(fields)

    fields["seasons"] = data["seasons"]
    fields["showID"] = data["showID"]

    displayInput("Season " .. "(1 - " .. fields["seasons"] .. ")", enteredSeasonNumber)
end

--local function enteredTVShow(show, err, flag)
--    if not show then return end
--    getSeasons(show)
--end

--mp.add_key_binding("p", "select-tvshow", function()
--    displayInput("TV Show", enteredTVShow)
--end)

mp.register_script_message("enter-show", function(show, linkPart)
    getSeasons(show)
    fields["part"] = linkPart
end)
