package = "mpris"
version = "scm-0"
source = { url = "git://github.com/dodo/lua-mpris.git" }
description = {
    summary = "mpris implementation",
    detailed = "Media Player Remote Interfacing Specification lua module",
    homepage = "https://github.com/dodo/lua-mpris",
    license = "MIT",
}
dependencies = { "lua >= 5.1", "lua-dbus >= scm-0" }
build = {
   type = "builtin",
    modules = {
        ['mpris'] = "init.lua",
        ['mpris.applet'] = "applet.lua",
        ['mpris.client'] = "client.lua",
   }
}
