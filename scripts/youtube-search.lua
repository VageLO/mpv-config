package.path = mp.command_native({ "expand-path", "~~/script-modules/?.lua;" }) .. package.path

local custom = require "custom-input"
local utils = require 'mp.utils'
local limit = 10

function search_youtube(filename)
    mp.commandv('loadfile', "ytdl://ytsearch" .. limit .. ":" .. filename, 'replace')
end

mp.add_key_binding("CTRL+SHIFT+s", "search_youtube", function ()
    custom.displayInput("Search on YouTube", search_youtube)
end)
