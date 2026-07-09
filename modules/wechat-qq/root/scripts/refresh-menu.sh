#!/bin/bash
# Regenerate openbox right-click menu from defaults + ~/Desktop/*.desktop files

MENU_DEFAULT="/defaults/menu.xml"
MENU_TARGET="/config/.config/openbox/menu.xml"
MENU_TMP="/tmp/menu.xml"

mkdir -p /config/.config/openbox
cp "$MENU_DEFAULT" "$MENU_TMP"

if ls "$HOME/Desktop/"*.desktop >/dev/null 2>&1; then
    for desktop_file in "$HOME/Desktop/"*.desktop; do
        name=$(grep -E "^Name=" "$desktop_file" | head -n 1 | cut -d "=" -f 2-)
        exec_cmd=$(grep -E "^Exec=" "$desktop_file" | head -n 1 | cut -d "=" -f 2-)
        icon=$(grep -E "^Icon=" "$desktop_file" | head -n 1 | cut -d "=" -f 2-)

        # skip entries without a name or exec command
        [ -z "$name" ] || [ -z "$exec_cmd" ] && continue

        # strip %U, %u, %F, %f field codes
        exec_cmd=$(echo "$exec_cmd" | sed 's/ %[fFuU]//g')

        # resolve icon path if it's just a name (not an absolute path)
        if [ -n "$icon" ] && [ "${icon#/}" = "$icon" ]; then
            icon_resolved=""
            # search in proot-apps icons (prefer 256x256)
            for size in 256x256 512x512 128x128 64x64 48x48 scalable; do
                found=$(find /config/proot-apps/*/usr/share/icons/hicolor/"$size"/apps/"$icon".* 2>/dev/null | head -n 1)
                if [ -n "$found" ]; then
                    icon_resolved="$found"
                    break
                fi
            done
            # fallback: search system icons
            if [ -z "$icon_resolved" ]; then
                found=$(find /usr/share/icons/hicolor/*/apps/"$icon".* 2>/dev/null | head -n 1)
                [ -n "$found" ] && icon_resolved="$found"
            fi
            [ -n "$icon_resolved" ] && icon="$icon_resolved"
        fi

        # handle missing icon
        [ -z "$icon" ] && icon="/usr/share/pixmaps/xterm-color_48x48.xpm"

        # escape XML entities
        exec_cmd=$(echo "$exec_cmd" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
        name=$(echo "$name" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')
        icon=$(echo "$icon" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g')

        sed -i "/<menu id=\"root-menu\" label=\"MENU\">/a \\<item label=\"${name}\" icon=\"${icon}\"><action name=\"Execute\"><command>${exec_cmd}</command></action></item>" "$MENU_TMP"
    done
fi

if [ ! -f "$MENU_TARGET" ] || ! cmp -s "$MENU_TMP" "$MENU_TARGET"; then
    cp "$MENU_TMP" "$MENU_TARGET"
    openbox --reconfigure 2>/dev/null || true
fi
