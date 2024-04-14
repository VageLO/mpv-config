seconds_to_replay = 2.5

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
utils = require 'mp.utils'
local json = require 'dkjson'
local input = require "user-input-module"

-- Read the JSON file
local file = io.open([[C:\Users\maksg\AppData\Roaming\mpv\scripts\config.json]], "r")
if file then
    local content = file:read("*a")
    file:close()

    -- Parse JSON into a Lua table
    config = json.decode(content)
else
    print("Failed to open the JSON file.")
end
---

PYTHON_HELPER_PATH = config.PYTHON_HELPER_PATH

function seconds_to_time(time)
    hours = math.floor(time / 3600)
    mins = math.floor(time / 60) % 60
    secs = math.floor(time % 60)
    milliseconds = (time * 1000) % 1000

    return string.format("%02d:%02d:%02d.%03d", hours, mins, secs, milliseconds)
end

function set_start_timestamp()
    start_timestamp = mp.get_property_number("time-pos")
    mp.osd_message("Start: " .. seconds_to_time(start_timestamp))
end

function set_end_timestamp()
    end_timestamp = mp.get_property_number("time-pos")
    mp.osd_message("End: " .. seconds_to_time(end_timestamp))
end

function reset_timestamps(flag)
    start_timestamp = nil
    end_timestamp = nil

    if timer ~= nil then
        timer:kill()
    end

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end

    if flag ~= "no-osd" then
        local ass_start = mp.get_property_osd("osd-ass-cc/0")
        mp.osd_message(ass_start .. "{\\1c&HE6E6E6&}●", 0.5)
    end
end

function replay_the_first_seconds()
    if start_timestamp ~= nil then
        mp.commandv("seek", start_timestamp, "absolute+exact")
        mp.set_property("pause", "no")
        player_state = "replay the first seconds"
    end
end

function replay_the_last_seconds()
    if end_timestamp ~= nil then
        mp.commandv("seek", end_timestamp - seconds_to_replay, "absolute+exact")
        mp.set_property("pause", "no")
        player_state = "replay the last seconds"
    end
end

function stop_playback()
    player_state = nil
    mp.set_property("pause", "yes")

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end
end

function playback_osd_message()
    mp.osd_message("●", 0.25)
end

function on_pause_change(name, value)
    if player_state == "replay" then
        if value == true then
            timer:stop()
        else
            timer:resume()
        end
    end
end

function on_seek()
    if timer ~= nil then
        timer:kill()
    end

    if periodic_timer ~= nil then
        periodic_timer:kill()
    end

    if player_state == "replay the last seconds" then
        periodic_timer = mp.add_periodic_timer(0.05, playback_osd_message)
    elseif player_state == "replay the first seconds" and end_timestamp ~= nil and end_timestamp > start_timestamp then
        periodic_timer = mp.add_periodic_timer(0.05, playback_osd_message)
    else
        player_state = nil
    end
end

function on_playback_restart()
    if player_state == "replay the first seconds" and end_timestamp == nil then
        player_state = nil
    elseif player_state == "replay the first seconds" and end_timestamp ~= nil and end_timestamp > start_timestamp then
        timer = mp.add_timeout(end_timestamp - start_timestamp, stop_playback)
        player_state = "replay"
    elseif player_state == "replay the last seconds" then
        timer = mp.add_timeout(seconds_to_replay, stop_playback)
        player_state = "replay"
    end
end

local function getWord(word, err, flag)
    if not word then return end
    create_anki_card(word)
end


function create_anki_card(word)

    word = string.match(word, "^%s*(.-)%s*$")
    
    mp.osd_message("🔃 Adding to Anki")

    local current_file = mp.get_property('path')
    local current_filename = mp.get_property('filename')
    local sub_text = mp.get_property("sub-text")
    local sub_track = 0
    local audio_track = 0
    local video_track = 0

    local track_list = mp.get_property_native("track-list")
    for _, track in ipairs(track_list) do
        if track.selected == true then
            if track.type == "sub" then
                sub_track = track["ff-index"]
            end
            if track.type == "audio" then
                audio_track = track["ff-index"]
            end
            if track.type == "video" then
                video_track = track["ff-index"]
            end
        end
    end
    
    local curr_time = mp.get_property_number("time-pos")
    if sub_text == nil then
        sub_text = ""
    end
    
    if start_timestamp == nil and end_timestamp == nil then
        start_timestamp = curr_time - seconds_to_replay
        end_timestamp = curr_time + seconds_to_replay
    elseif end_timestamp < start_timestamp then
        end_timestamp = curr_time + seconds_to_replay
    end

    local fields = {}
    
    fields["word"] = word
    fields["file"] = current_file
    fields["file_name"] = os.time() .. "_" .. current_filename 
    fields["aid"] = audio_track
    fields["sid"] = sub_track
    fields["vid"] = video_track
    fields["start_timestamp"] = start_timestamp
    fields["end_timestamp"] = end_timestamp
    fields["sub_text"] = sub_text

    local res = utils.format_json(fields)

    local args = {[[python]], PYTHON_HELPER_PATH, res}
    config.test = args
    ret = utils.subprocess({args = args})

    if ret["status"] == 0 then
        mp.osd_message("✔")
    else
        mp.osd_message(ret["stdout"])
    end

    start_timestamp = nil
    end_timestamp = nil
    -- mp.set_property("term-status-msg", status_msg)
    mp.add_timeout("0.25", reset_property)

    -- reset_timestamps("no-osd")
end

function reset_property()
    mp.set_property("term-status-msg", "")
end

mp.register_event("seek", on_seek)
mp.register_event("playback-restart", on_playback_restart)
mp.observe_property("pause", "bool", on_pause_change)

mp.add_key_binding("w", "set-start-timestamp", set_start_timestamp)
mp.add_key_binding("e", "set-end-timestamp", set_end_timestamp)
mp.add_key_binding("ctrl+w", "replay-the-first-seconds", replay_the_first_seconds)
mp.add_key_binding("ctrl+e", "replay-the-last-seconds", replay_the_last_seconds)
mp.add_key_binding("ctrl+r", "reset-timestamps", reset_timestamps)
mp.add_key_binding("b", "create-anki-card", function()
    mp.osd_message("🕳 Enter Word (not required)")
    input.get_user_input(getWord, {
        request_text = "❤ Word:",
        replace = true
    }, "replace")
end)