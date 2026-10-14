# Adjust the DankMaterialShell settings, applied by the workstation role with
# `jq -f dms-settings.jq`. DMS owns ~/.config/DankMaterialShell/settings.json
# and rewrites it as the shell is used, so the file is not symlinked from
# home/: it is patched here, and the keys DMS adds on its own are left alone.
#
# The layout is the one of the owner's sway setup, which DMS replaced on the
# Fedora MiracleWM spin (the spin ships its own defaults: dock on, bar inset
# by 4px and rounded, launcher button on the left, no workspace numbers, no
# date in the clock, no disk usage):
#   - dock off (the spin ships it on),
#   - workspace pills carry their index, like sway/waybar,
#   - clock: 24h and a short date (clockDateFormat is a Qt format string, it
#     goes to Qt's toLocaleDateString, not strftime),
#   - the bar is glued to the screen edges (spacing 0, square corners — the
#     spin insets it by its spacing and rounds it with Theme.cornerRadius
#     unless squareCorners),
#   - launcher button off the left, window title in the centre, clock at the
#     far right, disk usage on the right after memory.
#
# Every edit is guarded by `has()` / the widget lists so that a DMS version
# that drops or renames a key is left alone rather than written a null.

# dock off (the spin ships it on)
(if has("showDock") then .showDock = false else . end)
# workspace pills carry their index, like sway/waybar
| (if has("showWorkspaceIndex") then .showWorkspaceIndex = true else . end)
# clock: 24h, short date (reduced format; Qt "ddd dd/MM")
| (if has("use24HourClock") then .use24HourClock = true else . end)
| (if has("clockDateFormat") then .clockDateFormat = "ddd dd/MM" else . end)
# bar layout, per bar: launcher button off the left, window title in the
# centre, disk usage right after memory, clock at the far right
| (if (.barConfigs | type) == "array" and (.barConfigs | length) > 0 then
     .barConfigs = (.barConfigs | map(
       .spacing = 0
       | .squareCorners = true
       | .leftWidgets = ((.leftWidgets // []) - ["launcherButton", "focusedWindow"])
       | .centerWidgets = (["focusedWindow"] + ((.centerWidgets // []) - ["clock", "focusedWindow"]))
       | .rightWidgets = (((.rightWidgets // []) - ["clock"]) as $r
           | (if ($r | index("diskUsage")) != null then $r
              elif ($r | index("memUsage")) != null then
                ($r[0:(($r | index("memUsage")) + 1)] + ["diskUsage"] + $r[(($r | index("memUsage")) + 1):])
              else $r + ["diskUsage"] end) + ["clock"])
     ))
   else . end)
