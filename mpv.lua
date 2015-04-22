-- WORKAROUND find ldbus.so under ~/.config/mpv/scripts/
for path in package.path:gmatch(";([^;]+)") do
    if path:match(".config/mpv/scripts") then
        package.cpath = path:match("(.*)%.lua$") .. ".so;" .. package.cpath
    end
end

local Applet = require("mpris.applet")

local pid = tostring(mp):match(': (%w+)$') -- FIXME
local mpris = Applet:new({ name = "mpv", id = 'instance' .. pid })

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

local function update_title(name, title)
    local meta = mpris.property:get('metadata')
    if title or title ~= '' then
        meta['xesam:title'] = title
    else
        meta['xesam:title'] = nil
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

update_length('length', mp.get_property_number('length'))
mp.observe_property("length", 'number', update_length)

update_fullscreen('fullscreen', mp.get_property_bool('fullscreen'))
mp.observe_property("fullscreen", 'bool', update_fullscreen)
mpris.property:set('setfullscreen', true)


mpris.property:set('urischemes', mp.get_protocols and mp.get_protocols() or {})
mpris.property:set('mimetypes', mp.get_mimetypes and mp.get_mimetypes() or {}) -- TODO
