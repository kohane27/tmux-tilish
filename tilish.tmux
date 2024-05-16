#!/bin/sh
# vim: foldmethod=marker

# Project: tmux-tilish
# Author:  Jabir Ali Ouassou <jabirali@switzerlandmail.ch>
# Licence: MIT licence
#
# This file contains the `tmux` plugin `tilish`, which implements keybindings
# that turns `tmux` into a more typical tiling window manger for your terminal.
# The keybindings are taken nearly directly from `i3wm` and `sway`, but with
# minor adaptation to fit better with `vim` and `tmux`. See also the README.

# shellcheck disable=SC2016
# shellcheck disable=SC2086
# shellcheck disable=SC2250

# Define core functionality {{{
bind_switch() {
    # Bind keys to switch between workspaces.
    tmux $bind "$1" \
        if-shell "tmux select-window -t :$2" "" "new-window -t :$2"
}

bind_move() {
    # Bind keys to move panes between workspaces.
    tmux $bind "$1" \
        if-shell "tmux join-pane -t :$2" \
        "" \
        "new-window -dt :$2; join-pane -t :$2; select-pane -t top-left; kill-pane" \\\; select-layout \\\; select-layout -E
}

bind_layout() {
    if [ "$1" = '_' ]; then
        return
    fi

    # Bind keys to switch or refresh layouts.
    if [ "$2" = "zoom" ]; then
        # Invoke the zoom feature.
        tmux $bind "$1" \
            resize-pane -Z
    else
        # Actually switch layout.
        tmux $bind "$1" \
            select-layout "$2" \\\; select-layout -E
    fi
}

char_at() {
    # Finding the character at a given position in
    # a string in a way compatible with POSIX sh.
    echo $1 | cut -c $2
}
# }}}

# Check input parameters {{{
# Whether we need to use legacy workarounds (required before tmux 2.7).
legacy="$(tmux -V | grep -E 'tmux (1\.|2\.[0-6])')"

# Read user options.
for opt in \
    default dmenu easymode prefix shiftnum \
    navigate navigator \
    smart_splits smart_splits_dirs \
    layout_keys \
    refresh rename \
    refresh_hooks \
    new_pane; do
    export "$opt"="$(tmux show-option -gv @tilish-"$opt" 2>/dev/null)"
done

# Default to US keyboard layout, unless something is configured.
if [ -z "$shiftnum" ]; then
    shiftnum='!@#$%^&*()'
fi
if [ -z "$layout_keys" ]; then
    layout_keys='sSvVtz'
fi

# Resize hooks are enabled by default
if [ -z "$refresh_hooks" ]; then
    # First one is the 'after-split-window' hook
    # Second one is the 'pane-exited' hook
    refresh_hooks='yy'
fi

if [ -z "$refresh" ]; then refresh="r"; fi
if [ -z "$easymode" ]; then easymode="nn"; fi

if [ -z "$rename" ]; then
    rename="n"
elif [ "$rename" = '---' ]; then rename=''; fi

if [ -z "$new_pane" ]; then
    new_pane="enter"
elif [ "$new_pane" = '---' ]; then new_pane=''; fi

# Determine modifier vs. prefix key.
if [ -z "${prefix:-}" ]; then
    bind='bind -n'
    mod='M-'
else
    bind='bind -rT tilish'
    mod=''
fi
# }}}

# Define keybindings {{{
# Define a prefix key.
if [ -n "$prefix" ]; then
    tmux bind -n "$prefix" switch-client -T tilish
fi

# Switch to workspace via Alt + #.
bind_switch "${mod}1" 1
bind_switch "${mod}2" 2
bind_switch "${mod}3" 3
bind_switch "${mod}4" 4
bind_switch "${mod}5" 5
bind_switch "${mod}6" 6
bind_switch "${mod}7" 7
bind_switch "${mod}8" 8
bind_switch "${mod}9" 9

# The mapping of Alt + 0 and Alt + Shift + 0 depends on `base-index`.
# It can either refer to workspace number 0 or workspace number 10.
if [ "$(tmux show-option -gv base-index)" = "1" ]; then
    bind_switch "${mod}0" 10
    bind_move "${mod}$(char_at "$shiftnum" 10)" 10
else
    bind_switch "${mod}0" 0
    bind_move "${mod}$(char_at "$shiftnum" 10)" 0
fi

# Switch layout with Alt + <mnemonic key>.
# The keys can be overridden, but the default mnemonics are
# `s` and `S` for layouts Vim would generate with `:split`, and `v` and `V` for `:vsplit`.
# The remaining mappings based on `z` and `t` should be quite obvious.
layout_key_1=$(char_at $layout_keys 1)
layout_key_2=$(char_at $layout_keys 2)
layout_key_3=$(char_at $layout_keys 3)
layout_key_4=$(char_at $layout_keys 4)
layout_key_5=$(char_at $layout_keys 5)
layout_key_6=$(char_at $layout_keys 6)

[ $layout_key_1 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 1)" 'main-horizontal'
[ $layout_key_2 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 2)" 'even-vertical'
[ $layout_key_3 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 3)" 'main-vertical'
[ $layout_key_4 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 4)" 'even-horizontal'
[ $layout_key_5 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 5)" 'tiled'
[ $layout_key_6 = '_' ] || bind_layout "${mod}$(char_at $layout_keys 6)" 'zoom'

# Refresh the current layout (e.g. after deleting a pane).
tmux $bind "${mod}${refresh}" select-layout -E

# Open a terminal with Alt + <new_pane>
if [ -n "$new_pane" ]; then
    tmux $bind "${mod}${new_pane}" \
        run-shell 'cwd="`tmux display -p \"#{pane_current_path}\"`"; tmux select-pane -t "bottom-right"; tmux split-pane -c "$cwd"'
fi

# Define hooks {{{
if [ -z "$legacy" ]; then
    # Autorefresh layout after deleting a pane.
    if [ "$(char_at $refresh_hooks 1)" = 'y' ]; then
        tmux set-hook -g after-split-window "select-layout; select-layout -E"
    fi

    if [ "$(char_at $refresh_hooks 2)" = 'y' ]; then
        tmux set-hook -g pane-exited "select-layout; select-layout -E"
    fi

    # Autoselect layout after creating new window.
    if [ -n "${default:-}" ]; then
        tmux set-hook -g window-linked "select-layout \"$default\"; select-layout -E"
        tmux select-layout "$default"
        tmux select-layout -E
    fi
fi
# }}}
