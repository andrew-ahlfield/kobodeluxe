# dmgbuild settings for the macOS disk image: the app on the left, an
# arrow, and an Applications link on the right. Used by
# packaging/build-macos.sh, which passes the paths with -D:
#   app=<path to KoboDeluxe.app>  background=<png>  icon=<icns>
# The positions must match packaging/make-dmg-background.py.

import os

app = defines["app"]
app_name = os.path.basename(app)

format = "ULFO"
filesystem = "APFS"
files = [app]
symlinks = {"Applications": "/Applications"}
hide_extensions = [app_name]

icon = defines["icon"]
background = defines["background"]

window_rect = ((200, 160), (640, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False

arrange_by = None
icon_size = 128
text_size = 13
icon_locations = {
    app_name: (170, 185),
    "Applications": (470, 185),
}
