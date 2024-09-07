seconds_to_replay = 2.5

package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path
utils = require 'mp.utils'
local json = require 'dkjson'
local input = require "user-input-module"

-- Read the JSON file
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
---

PYTHON_HELPER_PATH = config.PYTHON_HELPER_PATH

local function getWord(word, err, flag)
    if not word then return end
    create_anki_card(word)
end


function create_anki_card(word)
    word = string.match(word, "^%s*(.-)%s*$")

    local current_file = mp.get_property('path')
    local current_filename = mp.get_property('filename')
    local sub_text = mp.get_property("sub-text")
    local sub_track = 0
    local audio_track = 0
    local video_track = 0

    if sub_text == "" and word == "" then
        mp.osd_message("Select subtitles or write word!💢")
        return
    end

    mp.osd_message("🔃 Adding to Anki")

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

    start_timestamp = curr_time - seconds_to_replay
    end_timestamp = curr_time + seconds_to_replay

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
    fields["config"] = scripts_dir .. "/config.json"

    local res = utils.format_json(fields)

    local args = { [[python]], PYTHON_HELPER_PATH, res }

    ret = utils.subprocess({ args = args })

    if ret["status"] == 0 then
        mp.osd_message("✔")
    else
        mp.osd_message(ret["stdout"], 2.0)
        mp.msg.error(ret["stdout"])
    end

    start_timestamp = nil
    end_timestamp = nil
    mp.add_timeout("0.25", function()
    end)
end

mp.add_key_binding("b", "create-anki-card", function()
    mp.osd_message("🕳 Enter Word (not required)")
    input.get_user_input(getWord, {
        request_text = "❤ Word:",
        replace = true
    }, "replace")
end)
