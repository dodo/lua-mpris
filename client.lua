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
    self.id = name:match('^org%.mpris%.MediaPlayer2%.(.*)$') or ''
    self.address = opts.address
    self.properties = {}
    self.name = name
    self.path = opts.path
    self.bus = opts.bus
    if not self.address then
        local player = self
        dbus.owner(name, function (address)
            player.address = address
            -- start listing deferred property changes
            for _, props in pairs(player.properties) do
                for _, prop in ipairs(props) do
                    dbus.property.on(prop.name, prop.handler, {
                        interface = INTERFACE[prop.interface],
                        sender = player.address,
                        bus = player.bus,
                    })
                end
            end
        end)
    end
end

function Player:call(iface, method, ...)
    if self.closed then return end
    dbus.call(method, { args = {...},
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:get(iface, name, callback)
    if self.closed then return end
    dbus.property.get(name, callback, {
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:set(iface, name, value)
    if self.closed then return end
    dbus.property.set(name, value, {
        interface = INTERFACE[iface],
        destination = self.name,
        path = self.path,
        bus = self.bus,
    })
end

function Player:change(iface, name, callback)
    if self.closed then return end
    local evname = string.format('%s.%s', iface, name)
    self.properties[evname] = self.properties[evname] or {}
    table.insert(self.properties[evname], {
        name = name,
        interface = iface,
        handler = callback,
    })
    self:get(iface, name, callback)
    if self.address then
        dbus.property.on(name, callback, {
            interface = INTERFACE[iface],
            sender = self.address,
            bus = self.bus,
        })
    end
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
    if self.closed then return end
    self.closed = true
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
    local client = self
    return self:getPlayerNames(function (names)
        client.players = {}
        for i, name in ipairs(names) do
            client.players[name] = Player:new(name, client)
        end
        return callback(client.players)
    end)
end

local function haz(t, value)
    for _, v in ipairs(t) do
        if v == value then
            return true
        end
    end
    return false
end

function Client:updatePlayers(callback)
    local client = self
    return self:getPlayerNames(function (names)
        local playernames = {}
        local added, removed, unchanged = {}, {}, {}
        for id, player in pairs(client.players) do
            table.insert(playernames, player.name)
            if haz(names, player.name) then
                table.insert(unchanged, player)
            else
                table.insert(removed, player)
                client.players[id] = nil
                player:close()
            end
        end
        for _, name in ipairs(names) do
            if not haz(playernames, name) then
                local player = Player:new(name, client)
                client.players[name] = player
                table.insert(added, player)
            end
        end
        return callback(added, removed, unchanged)
    end)
end

function Client:onPlayer(callback)
    local client = self
    local opts = setmetatable({}, { __index = client })
    return dbus.on('NameOwnerChanged', function (iface, removed, added)
        if tostring(iface):match('^org%.mpris%.MediaPlayer2%.') then
            local player = (client.players or {})[iface]
            if     added ~= '' and removed == '' then
                if not player then
                    opts.address = added
                    player = Player:new(iface, opts)
                    client.players[iface] = player
                end
            elseif added == '' and removed ~= '' then
                if player and player.address == removed then
                    client.players[iface] = nil
                    player:close()
                end
            elseif added ~= '' and removed ~= '' then
                if player and player.address == removed then
                    player.address = added
                end
            end
            if callback then
                return callback(player)
            end
        end
    end, { bus = self.bus, interface = 'org.freedesktop.DBus' })
end

return Client
