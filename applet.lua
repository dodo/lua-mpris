local dbus = require("lua-dbus.init")
local Interface = require("lua-dbus.interface")

if not awesome then dbus.init() end

local MPRIS = {
    path = '/org/mpris/MediaPlayer2',
    media = 'org.mpris.MediaPlayer2',
    player = 'org.mpris.MediaPlayer2.Player',
}


local function createinstance(meta, ...)
    local instance = setmetatable({}, meta)
    if instance.init then instance:init(...) end
    return instance
end

local function backcall(opts, name)
    return function (signal, ...)
        local callback = opts[name]
        if    callback then
            return callback(...)
        end
    end
end

local function haz(t, val)
    for i, v in ipairs(t) do
        if v == val then return i end
    end
end


local Properties = { new = createinstance }
Properties.__index = Properties

function Properties:init(app)
    self.properties = {}
    self.app = app
end

function Properties:get(name)
    return self.app.state[name]
end

function Properties:set(name, value)
    if self.app.state[name] ~= nil then
        self.app.state[name] = value
        -- emit PropertiesChanged signal
        for property_name, names in pairs(self.properties) do
            if haz(names, name) then
                self.app.interface:property(property_name, value, {
                    interface = names.interface,
                    path = MPRIS.path,
                })
            end
        end
        return true
    end
end

function Properties:sets(values)
    for name, value in pairs(values) do
        if self.app.state[name] ~= nil then
            self.app.state[name] = value
        end
    end
    local properties, keys = {}, {}
    -- emit PropertiesChanged signal
    for property_name, names in pairs(self.properties) do
        for name, value in pairs(values) do
            if haz(names, name) then
                keys[names.interface] = keys[names.interface] or {}
                properties[names.interface] = properties[names.interface] or {}
                properties[names.interface][property_name] = value
                table.insert(keys[names.interface], property_name)
                break
            end
        end
    end
    local ret = false
    for interface, names in pairs(keys) do
        if #names > 0 then
            self.app.interface:properties(names, properties[interface], {
                interface = interface,
                path = MPRIS.path,
            })
            ret = true
        end
    end
    return ret
end

function Properties:getter(names, property_name, interface)
    self.properties[property_name] = names
    names.interface = interface
    local properties = self
    return function ()
        local ret = nil
        for _, name in ipairs(names) do
            local value = properties.app.state[name]
            if value == nil then
                break
            elseif ret == nil then
                ret = value
            else
                ret = ret and value
            end
        end
        return ret
    end
end

function Properties:setter(name)
    local properties = self
    return function (value)
        if properties.app.state[name] ~= nil then
            properties.app.state[name] = value
            local update = properties.app.options['on' .. name]
            if update then update(value) end
        end
    end
end

function Properties:getters(interface, props)
    local properties = {}
    for name, opts in pairs(props) do
        local property = { type = opts.type }
        if opts.write then property.write = self:setter(opts.write) end
        if opts.read  then property.read  = self:getter(opts.read, name, interface) end
        properties[name] = property
    end
    return properties
end

local Applet = { new = createinstance }
Applet.__index = Applet
Applet.dbus = dbus
Applet.INTERFACE = MPRIS

function Applet:init(opts)
    opts = opts or {}
    opts.name = opts.name or "lua"
    if opts.id == nil then
        opts.id = "instance" .. tostring(self):match(': (%w+)$')
    end
    opts.id = opts.id and ("." .. opts.id) or ""
    self.options = opts
    self.property = Properties:new(self)
    self.interface = Interface:new({
        name = string.format('%s.%s%s', MPRIS.media, opts.name, opts.id),
        bus = 'session',
    })
    self.state = {
        identity      = opts.identity or opts.name,
        entry         = opts.entry or opts.name,
        status        = "Stopped",
        urischemes    = {},
        mimetypes     = {},
        metadata      = {},
        volume        = 0,
        minrate       = 1.0,
        maxrate       = 1.0,
        rate          = 1.0,
        raise         = false,
        quit          = true,
        control       = true,
        previous      = true,
        next          = true,
        pause         = true,
        play          = true,
        seek          = false,
        tracklist     = false,
        fullscreen    = false,
        setfullscreen = false,
    }
    self.interface:add({
        interface = MPRIS.media,
        path = MPRIS.path,
        methods = {
            Quit = {  callback = backcall(opts, 'quit')  },
            Raise = { callback = backcall(opts, 'raise') },
        },
        properties = self.property:getters(MPRIS.media, {
            Identity = { type = 's', read = {'identity'} },
            DesktopEntry = { type = 's', read = {'entry'} },
            HasTrackList = { type = 'b', read = {'tracklist'} },
            CanQuit = {  type = 'b', read = {'quit'}  },
            CanRaise = { type = 'b', read = {'raise'} },
            CanSetFullscreen = { type = 'b', read = {'control', 'setfullscreen'} },
            Fullscreen = { type = 'b', write = 'fullscreen',
                           read = {'control', 'setfullscreen', 'fullscreen'} },
            SupportedUriSchemes = { type = 'as', read = {'urischemes'} },
            SupportedMimeTypes = { type = 'as', read = {'mimetypes'} },
        }),
    })
    self.interface:add({
        interface = MPRIS.player,
        path = MPRIS.path,
        methods = {
            Stop      = { callback = backcall(opts, 'stop') },
            Play      = { callback = backcall(opts, 'play') },
            Pause     = { callback = backcall(opts, 'pause') },
            PlayPause = { callback = backcall(opts, 'playpause') },
            Previous  = { callback = backcall(opts, 'previous') },
            Next      = { callback = backcall(opts, 'next') },
            Seek      = {'x', "Offset", callback = backcall(opts, 'seek') },
            SetPosition = {'o', "TrackId", 'x', "Position", callback = backcall(opts, 'setposition') },
            OpenUri = {'s', "Uri", callback = backcall(opts, 'openuri') },
        },
        signals = {
            Seeked = { type = 'x' }, -- TODO
        },
        properties = self.property:getters(MPRIS.player, {
            PlaybackStatus = { type = 's', read = {'status'} },
            CanControl = { type = 'b', read = {'control'} },
            CanPlay = { type = 'b', read = {'control', 'play'} },
            CanPause = { type = 'b', read = {'control', 'pause'} },
            CanGoPrevious = { type = 'b', read = {'control', 'previous'} },
            CanGoNext = { type = 'b', read = {'control', 'next'} },
            CanSeek = { type = 'b', read = {'control', 'seek'} },
            Metadata = { type = 'a{sv}', read = {'metadata'} },
            Volume = { type = 'd', read = {'volume'}, write = 'volume' },
            MinimumRate = { type = 'd', read = {'minrate'} },
            MaximumRate = { type = 'd', read = {'maxrate'} },
            Rate = { type = 'd', read = {'rate'}, write = 'rate' },
        }),
    })
end


return Applet
