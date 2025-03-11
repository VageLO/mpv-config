package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local json = require 'dkjson'
local input = require "user-input-module"
local custom = require "custom-input"

local config = custom.loadConfig("config.json", "scripts")

if config == nil then
    print("Failed to open the JSON file.")
    return
end

UV_TVSHOWS_DIR = config.UV_TVSHOWS
UV_TVSHOWS = "tvshows.py"

local fields = {}

local function displayInput(message, func)
    mp.osd_message("🕳 Enter " .. message)

    input.get_user_input(func, {
        request_text = "❤ " .. message .. ":",
        replace = true
    }, "replace")
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

local function enteredEpisodeNumber(episode)
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

    local command = "'"..json.encode(args).."'"

    local data = custom.pythonCommand(
        command,
        UV_TVSHOWS_DIR,
        UV_TVSHOWS
    )
    data = custom.check(data)

    if data ~= nil then
        fields["episodes"] = data["episodes"]
        fields["url"] = data["url"]
        fields["sub"] = data["sub"]

        displayInput("Episode " .. "(1 - " .. fields["episodes"] .. ")", enteredEpisodeNumber)
    end
end

local function enteredSeasonNumber(season)
    if not season then return end
    getEpisodes(season)
end

local function getSeasons(tvshow)
    fields = {}
    fields["show"] = tvshow
    local command = "'"..json.encode(fields).."'"

    local data = custom.pythonCommand(
        command,
        UV_TVSHOWS_DIR,
        UV_TVSHOWS
    )
    data = custom.check(data)
    if data ~= nil then
        fields["seasons"] = data["seasons"]
        fields["showID"] = data["showID"]

        displayInput("Season " .. "(1 - " .. fields["seasons"] .. ")", enteredSeasonNumber)
    end
end

mp.register_script_message("enter-show", function(show, linkPart)
    getSeasons(show)
    fields["part"] = linkPart
end)
