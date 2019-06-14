-- WORKAROUND find ldbus.so under ~/.config/mpv/scripts/
for path in package.path:gmatch(";([^;]+)") do
    if path:match(".config/mpv/scripts") then
        package.cpath = path:match("(.*)%.lua$") .. ".so;" .. package.cpath
    end
end


local valid_utf8_sequences = { {{0,127}},
                               {{194,223}, {128,191}},
                               {     224 , {160,191}, {128,191}},
                               {{225,236}, {128,191}, {128,191}},
                               {     237 , {128,159}, {128,191}},
                               {{238,239}, {128,191}, {128,191}},
                               {     240 , {144,191}, {128,191}, {128,191}},
                               {{241,243}, {128,191}, {128,191}, {128,191}},
                               {     244 , {128,143}, {128,191}, {128,191}}
                             }

-- Returns the length (in bytes) of the character at (byte) position i of
-- the string str . Returns -1 if there's an invalid character at position i.
function utf8_char_length(str, i)
    local len = string.len(str)

    for k, sequence in pairs(valid_utf8_sequences) do
        if i + #sequence - 1 > len then
            return -1
        end
        ok = true
        for j, valid in pairs(sequence) do
            c = string.byte(str, i+j-1)
            if type(valid) == 'table' then
                if c < valid[1] or c > valid[2] then
                    ok = false
                    break
                end
            else
                if c ~= valid then
                    ok = false
                    break
                end
            end
        end
        if ok then
            return #sequence
        end
    end
    return -1
end


-- Returns the string str with invalid utf8 characters removed
function remove_invalid_utf8_chars(str)
    local i = 1
    local len = string.len(str)

    while i <= len do
        local seq = {}
        local char_length = utf8_char_length(str, i)
        if char_length > 0 then
            i = i + char_length
        else
            str = string.sub(str, 1, i - 1) .. string.sub(str, i + 1)
            len = len - 1
        end
    end

    return str
end

local Applet = require("lua-mpris.applet")
local mputils = require 'mp.utils'

local pid = tostring(mp):match(': (%w+)$') -- FIXME
local mpris = Applet:new({ name = "mpv", id = 'instance' .. pid })

local assignments = {{'xesam:album', 'metadata/by-key/album'},
                     {'xesam:albumArtist','metadata/by-key/album_artist'},
                     {'xesam:artist','metadata/by-key/artist'},
                     {'xesam:trackNumber','metadata/by-key/track'},
                     {'xesam:genre','metadata/by-key/genre'},
                     {'xesam:lyricist','metadata/by-key/lyricist'},
                     {'xesam:discNumber','metadata/by-key/disc'}}

local cover_filenames = {'cover.jpg', 'cover.png', 'folder.jpg', 'folder.png', 'front.jpg', 'front.png'}

--- sync

mp.add_periodic_timer(0.1, function () mpris.dbus.poll() end)
mp.register_event('shutdown', function() mpris.dbus.exit() end)

--- methods

function mpris.options.next()
    mp.command("playlist_next")
end

function mpris.options.previous()
    mp.command("playlist_prev")
end

function mpris.options.stop()
    mp.command("stop")
end

function mpris.options.pause()
    mp.set_property_bool('pause', true)
end

function mpris.options.playpause()
    local paused = mp.get_property_bool('pause')
    mp.set_property_bool('pause', not paused)
end

function mpris.options.play()
    if mp.get_property_bool('pause') then
        mp.set_property_bool('pause', false)
    end
end

function mpris.options.seek(offset)
    if type(offset) == 'number' then
        -- offset is in microseconds
        mp.commandv("seek", offset / 1e6)
    end
end

function mpris.options.position()
    value = mp.get_property_number('time-pos')
    if value then
        return value * 1e6
    end
    return 0
end

function mpris.options.setposition(trackid, position)
    if type(position) == 'number' then
        -- position is in microseconds
        mp.commandv("seek", position / 1e6, "absolute")
    end
end

function mpris.options.openuri(uri)
    if type(uri) == 'string' then
        mp.commandv("loadfile", uri)
    end
end

function mpris.options.quit()
    mp.command("quit")
end

function mpris.options.onvolume(vol)
    mp.set_property_number('volume', (vol or 0) * 100)
end

function mpris.options.onfullscreen(isfullscreen)
    mp.set_property_bool('fullscreen', not not isfullscreen)
end

--- properties

local function update_volume(name, value)
    local vol = (value or 0) * 0.01
    if vol ~= mpris.property:get('volume') then
        mpris.property:set('volume', vol)
    end
end

local function update_pause(name, paused)
    mpris.property:sets({
        status = (paused and "Paused" or "Playing"),
        pause = not paused,
        play = paused,
    })
end

local function update_idle(name, idle)
    if idle then
        mpris.property:sets({
            status = "Stopped",
            previous = false,
            next = false,
            pause = false,
            play = false,
        })
    end
end

local function table_contains(table, item)
    if table then
        for key, value in pairs(table) do
            if value == item then return key end
        end
    end
    return false
end


local function update_title(name, title)
    local meta = mpris.property:get('metadata')
    if title or title ~= '' then
        meta['xesam:title'] = remove_invalid_utf8_chars(title)
    else
        meta['xesam:title'] = nil
    end
    for k,assignment in pairs(assignments) do
        value = mp.get_property(assignment[2])
        if value or value ~= '' then
            if type(value) == 'string' then
                meta[assignment[1]] = remove_invalid_utf8_chars(value)
            else
                meta[assignment[1]] = value
            end
        else
            meta[assignment[1]] = nil
        end
    end

    meta['mpris:trackid'] = '/org/mpv/Track/123456'
    meta['mpris:artUrl'] = nil
    meta['xesam:url'] = nil
    path = mp.get_property('path')
    if path or path ~= '' then
        cwd = mputils.getcwd()
        meta['xesam:url'] = mputils.join_path(cwd, path)
        local dir, fname = mputils.split_path(path)
        files = mputils.readdir(dir)
        for _ , cover_filename in pairs(cover_filenames) do
            if table_contains(files, cover_filename) then
                meta['mpris:artUrl'] = mputils.join_path(mputils.join_path(cwd, dir), cover_filename)
                break;
            end
        end
    end
    mpris.property:set('metadata', meta)
end

local function update_length(name, len)
    local meta = mpris.property:get('metadata')
    if len then
        meta['mpris:length'] = math.floor(len * 1e6) -- microseconds
    else
        meta['mpris:length'] = nil
    end
    mpris.property:set('metadata', meta)
end

local function update_fullscreen(name, isfullscreen)
    mpris.property:set('fullscreen', isfullscreen)
end

update_volume('volume', mp.get_property_number('volume'))
mp.observe_property("volume", 'number', update_volume)

update_pause('pause', mp.get_property_bool('pause'))
mp.observe_property("pause", 'bool', update_pause)

update_idle('idle', mp.get_property_bool('idle'))
mp.observe_property("idle", 'bool', update_idle)

-- will be set later. always.
mp.observe_property("metadata/icy-title", 'string', update_title)
mp.observe_property("media-title", 'string', update_title)

update_length('duration', mp.get_property_number('duration'))
mp.observe_property("duration", 'number', update_length)

update_fullscreen('fullscreen', mp.get_property_bool('fullscreen'))
mp.observe_property("fullscreen", 'bool', update_fullscreen)
mpris.property:set('setfullscreen', true)


mpris.property:set('urischemes', mp.get_protocols and mp.get_protocols() or {})
mpris.property:set('mimetypes', mp.get_mimetypes and mp.get_mimetypes() or {}) -- TODO
