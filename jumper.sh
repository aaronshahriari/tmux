#!/usr/bin/env bash
# Usage: jumper.sh <dir> [layout]
#   <dir>     directory to jump to; session is named after its basename
#   [layout]  optional layout name -> applied (only on session creation) from
#             ~/.config/tmux-sessionizer/layouts/<layout>.tmux-sessionizer.conf
#             (same format as tmux-sessionizer: one "window <name> [cmd...]" per line)

target_path="$1"
layout="$2"
session_name="$(basename "$target_path")"

LAYOUT_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux-sessionizer/layouts"

# Build windows in a freshly-created session from a layout file. Each window
# starts a shell in the target dir, then the optional command is sent to it so
# the window persists after the command exits.
apply_layout() {
    local session="$1" dir="$2" layout_file="$3"
    local bootstrap first_win="" created=0
    bootstrap=$(tmux list-windows -t "$session" -F '#{window_id}' 2>/dev/null | head -1)

    while IFS= read -r raw || [[ -n "$raw" ]]; do
        local trimmed="${raw#"${raw%%[![:space:]]*}"}"
        [[ -z "$trimmed" || "$trimmed" == '#'* ]] && continue
        local kw name cmd
        read -r kw name cmd <<< "$trimmed"
        [[ "$kw" == "window" && -n "$name" ]] || continue

        local win_id
        win_id=$(tmux new-window -d -P -F '#{window_id}' -n "$name" -c "$dir" -t "$session:")
        created=$((created + 1))
        [[ -z "$first_win" ]] && first_win="$win_id"
        [[ -n "$cmd" ]] && tmux send-keys -t "$win_id" "$cmd" C-m
    done < "$layout_file"

    if [[ "$created" -gt 0 && -n "$bootstrap" ]]; then
        tmux kill-window -t "$bootstrap" 2>/dev/null
        # killing the bootstrap leaves the layout windows at 2,3,4; renumber them
        # so they start at base-index (1,2,3)
        tmux move-window -r -t "$session" 2>/dev/null
        [[ -n "$first_win" ]] && tmux select-window -t "$first_win" 2>/dev/null
    fi
}

if ! tmux has-session -t "$session_name" 2>/dev/null; then
    tmux new-session -d -s "$session_name" -c "$target_path"
    layout_file="$LAYOUT_DIR/$layout.tmux-sessionizer.conf"
    if [[ -n "$layout" && -f "$layout_file" ]]; then
        apply_layout "$session_name" "$target_path" "$layout_file"
    fi
fi

tmux switch-client -t "$session_name"
