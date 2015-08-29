# [mpris](https://github.com/dodo/lua-mpris)

[Media Player Remote Interfacing Specification](http://specifications.freedesktop.org/mpris-spec/latest/) lua module.

Client and Player interface implemented.

Requires [lua-dbus](https://github.com/dodo/lua-dbus).

## installation

```bash
# i686 and Arch:
luarocks install --local --server=http://rocks.moonscript.org/manifests/daurnimator ldbus DBUS_INCDIR=/usr/include/dbus-1.0/ DBUS_ARCH_INCDIR=/usr/lib/dbus-1.0/include

# x86_64:
luarocks install --local --server=http://rocks.moonscript.org/manifests/daurnimator ldbus DBUS_INCDIR=/usr/include/dbus-1.0/ DBUS_ARCH_INCDIR=/usr/lib/x86_64-linux-gnu/dbus-1.0/include

luarocks install --local --server=http://luarocks.org/manifests/dodo lua-dbus
luarocks install --local --server=http://luarocks.org/manifests/dodo mpris
```

## mpv

`lua-mpris` comes with the file `mpv.lua` which is a plugin for [mpv](http://mpv.io).

Install that file into ~/.config/mpv/scripts by simply doing:
```bash
mkdir -p ~/.config/mpv/scripts/

wget \
'https://raw.githubusercontent.com/dodo/lua-mpris/master/mpv.lua' \
-O ~/.config/mpv/scripts/mpris.lua
```

## todo

* DOCUMENTATION
* org.mpris.MediaPlayer2.Player.Seeked
* org.mpris.MediaPlayer2.Playlists
* org.mpris.MediaPlayer2.TrackList
