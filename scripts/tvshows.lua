package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local custom = require "custom-input"

local VIDEO_URL = "https://s3.streamani.top/video1/BhcfuSh5dWKu9KmZ1jh_jg/1734188744/"

local fields = {}
local Menu = "tvshows"

local function curl(href, options)
    options = options or ""
    local command = [[curl]]
        .. " " .. options .. " " .. href
    local handle = io.popen(command)

    local result = handle:read("*a")
    handle:close()

    return result
end

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

mp.register_script_message("get_episodes", function(selected_season)
    local num = tonumber(selected_season)
    if num == nil then
        mp.osd_message("Conversion faild", 1)
        return
    end

    selected_season = num
    local seasons_href = "https://api.tvmaze.com/shows/" .. fields["showID"] .. "/seasons"

    local seasons_response = curl(seasons_href)
    seasons_response = custom.check(seasons_response)

    if not seasons_response then
        return
    end

    local episodes_from_api = 0
    for _, season in ipairs(seasons_response) do
        if season.number ~= selected_season then
            goto continue
        end

        if season.episodeOrder ~= nil then
            episodes_from_api = season.episodeOrder
            break
        end

        local season_url = season._links.self.href

        local season_res = curl(season_url .. "/episodes")
        season_res = custom.check(season_res)

        episodes_from_api = #season_res
        break

        ::continue::
    end

    local episodes = 0
    for num = 1, episodes_from_api do
        local num_str = num
        if num < 10 then
            num_str = "0" .. num
        end
        local url = VIDEO_URL .. fields["part"] .. "/" .. selected_season .. "/original/" .. selected_season .. num_str .. ".mp4"

        local episode_response = curl(url, "-s -o /dev/null -I -w '{\"code\": %{http_code}}'")
        episode_response = custom.check(episode_response)

        if episode_response.code ~= 200 then
            goto continue
        end

        episodes = episodes + 1
        ::continue::
    end

    fields["episodes"] = episodes
    fields["url"] = VIDEO_URL .. fields["part"] .. "/" .. selected_season .. "/original/" .. selected_season
    fields["sub"] = "https://" .. fields["part"] .. ".mult-fan.tv/captions/eng/" .. selected_season .. "/"

    display(fields["episodes"], "open_episode")
end)

local function getSeasons(tvshow)
    fields = {}
    local command = "https://api.tvmaze.com/singlesearch/shows?q=" .. tvshow

    local show_response = curl(command)
    show_response = custom.check(show_response)

    if not show_response then
        return
    end

    local last_episode = curl(show_response["_links"]["previousepisode"]["href"])
    last_episode = custom.check(last_episode)

    if not last_episode then
        return
    end

    fields["seasons"] = last_episode["season"]
    fields["showID"] = show_response["id"]

    display(fields["seasons"], "get_episodes")
end

mp.register_script_message("enter-show", function(show, linkPart)
    getSeasons(show)
    fields["part"] = linkPart
end)
