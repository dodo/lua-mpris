local dbus = require("lua-dbus")

local INTERFACE = {
    media = 'org.mpris.MediaPlayer2',
    track = 'org.mpris.MediaPlayer2.TrackList',
    player = 'org.mpris.MediaPlayer2.Player',
    playlist = 'org.mpris.MediaPlayer2.PlayLists',
}

local function createinstance(meta, ...)
    local instance = setmetatable({}, meta)
    if instance.init then instance:init(...) end
    return instance
end

local Player = { new = createinstance }
Player.__index = Player

function Player:init(name, opts)
    print("new player", name, opts.path, opts.bus)
    self.id = name:match('^org%.mpris%.MediaPlayer2%.(.*)$') or ''
    self.properties = {}
    self.name = name
    self.path = opts.path
    self.bus = opts.bus
end

function Player:call(iface, method, ...)
    dbus.call(method, { args = {...},
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:get(iface, name, callback)
    dbus.property.get(name, callback, {
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:set(iface, name, value)
    dbus.property.set(name, value, {
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:change(iface, name, callback)
    local evname = string.format('%s.%s', iface, name)
    self.properties[evname] = self.properties[evname] or {}
    table.insert(self.properties[evname], {
        name = name,
        interface = iface,
        handler = callback,
    })
    self:get(iface, name, callback)
    dbus.property.on(name, callback, {
        interface = INTERFACE[iface],
        sender = self.name,
        bus = self.bus,
    })
end

function Player:raise()
    self:call('media', 'Raise')
end

function Player:quit()
    self:call('media', 'Quit')
end

function Player:play()
    self:call('player', 'Play')
end

function Player:pause()
    self:call('player', 'Pause')
end

function Player:playpause()
    self:call('player', 'PlayPause')
end

function Player:stop()
    self:call('player', 'Stop')
end

function Player:previous()
    self:call('player', 'Previous')
end

function Player:next()
    self:call('player', 'Next')
end

function Player:seek(offset)
    self:call('player', 'Seek', 'x', offset)
end

function Player:position(trackid, position)
    self:call('player', 'SetPosition', 'o', trackid, 'x', position)
end

function Player:uri(uri)
    self:call('player', 'OpenUri', 's', uri)
end

function Player:close()
    for _, prop in pairs(self.properties) do
        for _, ev in ipairs(prop) do
            dbus.property.off(ev.name, ev.handler,  {
                interface = INTERFACE[ev.interface],
                sender = self.name,
                bus = self.bus,
            })
        end
    end
end


local Client = { new = createinstance }
Client.__index = Client
Client.Player = Player
Client.dbus = dbus

function Client:init()
    self.bus = 'session'
    self.path = '/org/mpris/MediaPlayer2'
end

function Client:getPlayerNames(callback)
    return dbus.call('ListNames', function (names)
        local players = {}
        if type(names) == 'table' then
            for _, name in ipairs(names) do
                if tostring(name):match('^org%.mpris%.MediaPlayer2%.') then
                    table.insert(players, name)
                end
            end
        end
        return callback(players)
    end, {
        path = '/',
        bus  = self.bus,
        destination = 'org.freedesktop.DBus',
        interface   = 'org.freedesktop.DBus',
    })
end

function Client:getPlayers(callback)
    local opts = self
    return self:getPlayerNames(function (names)
        local players = {}
        for i, name in ipairs(names) do
            players[name] = Player:new(name, opts)
        end
        return callback(players)
    end)
end

return Client
