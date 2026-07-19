# >>> hitch shell integration >>>
if not functions -q __hitch_original_fish_prompt
    functions -c fish_prompt __hitch_original_fish_prompt
end

function fish_prompt
    if set -q HITCH_SESSION
        set_color green
        printf '#%s ' $HITCH_SESSION
        set_color normal
    end
    __hitch_original_fish_prompt
end

function __hitch_run
        set -l __hitch_command $argv[1]
        set -e argv[1]
        set -l __hitch_bin (command -s "$__hitch_command")
        if test -z "$__hitch_bin"
            printf '%s: command not found\n' "$__hitch_command" >&2
            return 127
        end
        if not set -q HITCH_SESSION
            if test (count $argv) -eq 0; or test "$argv[1]" = on; or test "$argv[1]" = start
                history save 2>/dev/null
            end
        end

        set -l __hitch_cwd_file
        if not set -q HITCH_SESSION
            set __hitch_cwd_file (mktemp -t hitch-cwd.XXXXXX 2>/dev/null)
            if test -n "$__hitch_cwd_file"
                env HITCH_CWD_SYNC_FILE="$__hitch_cwd_file" "$__hitch_bin" $argv
            else
                "$__hitch_bin" $argv
            end
        else
            "$__hitch_bin" $argv
        end
        set code $status
        if test -n "$__hitch_cwd_file"; and test -s "$__hitch_cwd_file"
            set -l __hitch_cwd (cat "$__hitch_cwd_file" 2>/dev/null)
            if test -d "$__hitch_cwd"
                cd "$__hitch_cwd"
            end
        end
        if test -n "$__hitch_cwd_file"
            rm -f "$__hitch_cwd_file"
        end
        if test $code -eq 42
            exit
        end
        return $code
end

function hitch
    __hitch_run hitch $argv
end

alias unhitch 'hitch off'

function hitch-dev
    __hitch_run hitch-dev $argv
end
# <<< hitch shell integration <<<
