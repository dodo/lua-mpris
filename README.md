# [mpris](https://github.com/dodo/lua-mpris)

[Media Player Remote Interfacing Specification](http://specifications.freedesktop.org/mpris-spec/latest/) lua module.

Client and Player interface implemented.

Requires [lua-dbus](https://github.com/dodo/lua-dbus).

## installation

```bash
luarocks install --local --server=http://rocks.moonscript.org/manifests/daurnimator ldbus DBUS_INCDIR=/usr/include/dbus-1.0/ DBUS_ARCH_INCDIR=/usr/lib/dbus-1.0/include
#                                                                                                                    or x64: DBUS_ARCH_INCDIR=/usr/lib/x86_64-linux-gnu/dbus-1.0/include
luarocks install --local --server=http://luarocks.org/manifests/dodo lua-dbus
luarocks install --local --server=http://luarocks.org/manifests/dodo mpris
```

## mpv

`lua-mpris` comes with the file `mpv.lua` which is a plugin for [mpv](http://mpv.io).

Install that file into ~/.config/mpv/scripts by simply doing:
```bash
ln -s /path/to/lua-mpris/mpv.lua ~/.config/mpv/scripts/dbus.lua # cp works as well

# when using mpv with lua5.2 under debian best you add the dependencies direclty:

cd ~/.config/mpv/scripts
git clone https://github.com/dodo/lua-dbus
git clone https://github.com/dodo/lua-mpris mpris
git clone https://github.com/dodo/ldbus

cd ldbus
luarocks make --local ldbus-scm-0.rockspec LUA_INCDIR=/usr/include/lua5.2 DBUS_INCDIR=/usr/include/dbus-1.0/ DBUS_ARCH_INCDIR=/usr/lib/dbus-1.0/include
#                                                                                                    or x64: DBUS_ARCH_INCDIR=/usr/lib/x86_64-linux-gnu/dbus-1.0/include
cd ..
ln -s ldbus/ldbus.so

ln -s mpris/mpv.lua dbus.lua

```

## todo

* DOCUMENTATION
* org.mpris.MediaPlayer2.Player.Seeked
* org.mpris.MediaPlayer2.Playlists
* org.mpris.MediaPlayer2.TrackList
