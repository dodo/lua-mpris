# [mpris](https://github.com/dodo/lua-mpris)

[Media Player Remote Interfacing Specification](http://specifications.freedesktop.org/mpris-spec/latest/) lua module.

Client and Player interface implemented.

Requires [lua-dbus](https://github.com/dodo/lua-dbus).

## mpv

`lua-mpris` comes with the file `mpv.lua` which is a plugin for [mpv](http://mpv.io).

Install that file into ~/.config/mpv/scripts by simply doing:
```bash
ln -s /path/to/lua-mpris/mpv.lua ~/.config/mpv/scripts/dbus.lua # cp works as well
```

## todo

* DOCUMENTATION
* org.mpris.MediaPlayer2.Player.Seeked
* org.mpris.MediaPlayer2.Playlists
* org.mpris.MediaPlayer2.TrackList
