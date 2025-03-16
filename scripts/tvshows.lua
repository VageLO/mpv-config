package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local json = require 'dkjson'
local custom = require "custom-input"

local config = custom.loadConfig("config.json", "scripts")

if config == nil then
    print("Failed to open the JSON file.")
    return
end

UV_TVSHOWS_DIR = config.UV_TVSHOWS
UV_TVSHOWS = "tvshows.py"

local fields = {}
local Menu = "tvshows"

local function display(data, script_name)
    mp.commandv("script-message-to", "osm", "clear-menu", Menu)
    for item = 1, data do
        local command = string.format(
            "script-message-to %s %s %s",
            Menu,
            script_name,
            item
        )
        mp.commandv(
            "script-message-to",
            "osm",
            "add-to-menu",
            Menu,
            tostring(item),
            command
        )
    end

    mp.commandv("script-message-to", "osm", "show-menu", Menu)
end

mp.register_script_message("open_episode", function(episode)
    local num = tonumber(episode)
    if num == nil then
        mp.osd_message("Conversion faild", 1)
        return
    end

    episode = num

    if episode < 10 then
        episode = "0" .. episode
    end

    mp.commandv("loadfile", fields["url"] .. episode .. ".mp4")
    mp.command("set pause no")
end)

mp.register_event("file-loaded", function ()
    local filename = mp.get_property('filename')
    local parts = custom.split(filename, "%.")
    local sub = fields["sub"] .. parts[1] .. ".vtt"
    custom.file_loaded(sub)
end)

mp.register_script_message("get_episodes", function(season)
    local num = tonumber(season)
    if num == nil then
        mp.osd_message("Conversion faild", 1)
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

        display(fields["episodes"], "open_episode")
    end
end)

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

        display(fields["seasons"], "get_episodes")
    end
end

mp.register_script_message("enter-show", function(show, linkPart)
    getSeasons(show)
    fields["part"] = linkPart
end)
