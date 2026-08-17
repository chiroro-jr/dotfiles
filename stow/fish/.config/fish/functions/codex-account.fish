function __codex_account_init_vars
    set -g __codex_account_program codex-account

    set -g __codex_account_codex_home "$HOME/.codex"
    if set -q CODEX_HOME
        set __codex_account_codex_home "$CODEX_HOME"
    end

    set -g __codex_account_codex_auth_file "$__codex_account_codex_home/auth.json"
    if set -q AUTH_FILE
        set __codex_account_codex_auth_file "$AUTH_FILE"
    end

    set -g __codex_account_pi_home "$HOME/.pi/agent"
    if set -q PI_CODING_AGENT_DIR
        set __codex_account_pi_home "$PI_CODING_AGENT_DIR"
    end

    set -g __codex_account_pi_auth_file "$__codex_account_pi_home/auth.json"

    set -g __codex_account_opencode_home "$HOME/.local/share/opencode"
    if set -q XDG_DATA_HOME
        set __codex_account_opencode_home "$XDG_DATA_HOME/opencode"
    end
    if set -q OPENCODE_DATA
        set __codex_account_opencode_home "$OPENCODE_DATA"
    end
    set -g __codex_account_opencode_auth_file "$__codex_account_opencode_home/auth.json"

    set -g __codex_account_dir "$__codex_account_codex_home/.codex-account"
    if set -q CODEX_ACCOUNT_DIR
        set __codex_account_dir "$CODEX_ACCOUNT_DIR"
    end

    set -g __codex_account_accounts_home "$__codex_account_dir/accounts"
    if set -q CODEX_ACCOUNTS_HOME
        set __codex_account_accounts_home "$CODEX_ACCOUNTS_HOME"
    end
end

function __codex_account_die
    printf 'Error: %s\n' "$argv" >&2
    return 1
end

function __codex_account_note
    printf '%s\n' "$argv"
end

function __codex_account_usage
    printf '%s\n' \
        "$__codex_account_program - save and switch one ChatGPT login for Pi, Codex, and OpenCode" \
        '' \
        'Usage:' \
        "  $__codex_account_program help" \
        "  $__codex_account_program list" \
        "  $__codex_account_program current" \
        "  $__codex_account_program save [-a|--from AGENT] [-n|--name NAME]" \
        "  $__codex_account_program switch [-n|--name] NAME" \
        "  $__codex_account_program login [-a|--agent AGENT] [--device] [-n|--name NAME]" \
        "  $__codex_account_program sync" \
        "  $__codex_account_program refresh [-n|--name NAME]" \
        "  $__codex_account_program usage [-a|--agent AGENT] [-n|--name NAME] [--json]" \
        "  $__codex_account_program rm [-n|--name] NAME" \
        '' \
        'Commands:' \
        '  list' \
        '      List saved accounts. * is the live Pi login.' \
        '' \
        '  current' \
        '      Show live Pi, Codex, and OpenCode logins, and whether they share one grant.' \
        '' \
        '  save [-a AGENT] [-n NAME]' \
        '      Snapshot live tokens into the shared store as email.plan (from the token).' \
        '      Default saves every live tool. -a pi|codex|opencode saves that live file only.' \
        '' \
        '  switch NAME' \
        '      Put that saved grant on Pi, Codex, and OpenCode.' \
        '' \
        '  login [--device] [-n NAME]' \
        '      ChatGPT OAuth via Pi, then write the same grant to Codex and OpenCode.' \
        '      Use -a codex only for the official Codex login UI (hides live Codex' \
        '      first so `codex login` cannot revoke a saved account).' \
        '' \
        '  sync' \
        '      If Pi, Codex, and OpenCode are the same ChatGPT account, copy the newer' \
        '      tokens (Pi wins ties) to all three tools and the matching save. Refuses' \
        '      if they are different accounts.' \
        '' \
        '  refresh [-n NAME]' \
        '      Rotate tokens with OpenAI. Default is live Pi. Writes back to every' \
        '      live file on that same account, plus matching saves.' \
        '' \
        '  usage [-n NAME] [--json]' \
        '      Show ChatGPT Codex plan usage for each distinct account.' \
        '' \
        '  rm NAME' \
        '      Delete a saved account. Live files are left alone.' \
        '' \
        'Examples:' \
        "  $__codex_account_program login" \
        "  $__codex_account_program login --device -n work" \
        "  $__codex_account_program switch myworklink1@gmail.com.plus" \
        "  $__codex_account_program sync" \
        "  $__codex_account_program refresh" \
        "  $__codex_account_program save" \
        "  $__codex_account_program usage" \
        '' \
        'Storage:' \
        "  $__codex_account_accounts_home/<name>.json" \
        '' \
        'Notes:' \
        '  - Pi owns login and is the usual source of truth; Codex and OpenCode get converted copies.' \
        '  - `codex login` revokes whatever is in ~/.codex/auth.json. Prefer' \
        "    `$__codex_account_program login` instead of raw `codex login`." \
        '  - Do not run `codex logout` if you still want that saved account.' \
        '  - Pi restore only replaces openai-codex; cursor and other providers stay.' \
        '  - OpenCode restore only replaces openai; other OpenCode providers stay.' \
        '  - Restart Pi/Codex/OpenCode after switching.'
end

function __codex_account_helper_path
    printf '%s\n' "$HOME/.config/fish/functions/__codex_account.py"
end

function __codex_account_py
    set -l helper (__codex_account_helper_path)
    if not test -f "$helper"
        __codex_account_die "Missing helper $helper. Restow fish dotfiles."
        return 1
    end
    python3 "$helper" $argv
end

function __codex_account_py_store
    __codex_account_py $argv \
        --accounts-home "$__codex_account_accounts_home" \
        --codex-live "$__codex_account_codex_auth_file" \
        --pi-live "$__codex_account_pi_auth_file" \
        --opencode-live "$__codex_account_opencode_auth_file"
end

function __codex_account_normalize_agent
    switch (string lower -- "$argv[1]")
        case codex
            printf 'codex\n'
        case pi
            printf 'pi\n'
        case opencode
            printf 'opencode\n'
        case '*'
            __codex_account_die "Unknown agent '$argv[1]'. Use 'codex', 'pi', or 'opencode'."
            return 1
    end
end

function __codex_account_saved_path
    printf '%s/%s.json\n' "$__codex_account_accounts_home" "$argv[1]"
end

function __codex_account_live_auth_file
    switch "$argv[1]"
        case codex
            printf '%s\n' "$__codex_account_codex_auth_file"
        case pi
            printf '%s\n' "$__codex_account_pi_auth_file"
        case opencode
            printf '%s\n' "$__codex_account_opencode_auth_file"
    end
end

function __codex_account_current_file
    printf '%s/.current\n' "$__codex_account_dir"
end

function __codex_account_ensure_dirs
    mkdir -p "$__codex_account_codex_home" "$__codex_account_dir" "$__codex_account_accounts_home"
    chmod 700 "$__codex_account_dir" 2>/dev/null; or true
    chmod 700 "$__codex_account_accounts_home" 2>/dev/null; or true
    __codex_account_migrate_unscoped_layout
    __codex_account_py migrate-store "$__codex_account_accounts_home"
    or return 1
    __codex_account_restore_stashed_codex_if_needed
end

function __codex_account_codex_stash_path
    printf '%s/.live-codex-stash.json\n' "$__codex_account_dir"
end

function __codex_account_restore_stashed_codex_if_needed
    set -l stash (__codex_account_codex_stash_path)
    test -f "$stash"; or return 0
    if test -f "$__codex_account_codex_auth_file"
        rm -f "$stash"
        return 0
    end
    mv "$stash" "$__codex_account_codex_auth_file"
    chmod 600 "$__codex_account_codex_auth_file" 2>/dev/null; or true
    __codex_account_note 'Restored Codex auth left behind by an interrupted login.'
end

function __codex_account_hide_live_codex
    set -l stash (__codex_account_codex_stash_path)
    if test -f "$__codex_account_codex_auth_file"
        mv "$__codex_account_codex_auth_file" "$stash"
        chmod 600 "$stash" 2>/dev/null; or true
        return 0
    end
    return 1
end

function __codex_account_unhide_live_codex
    set -l stash (__codex_account_codex_stash_path)
    test -f "$stash"; or return 1
    if test -f "$__codex_account_codex_auth_file"
        rm -f "$stash"
        return 0
    end
    mv "$stash" "$__codex_account_codex_auth_file"
    chmod 600 "$__codex_account_codex_auth_file" 2>/dev/null; or true
end

function __codex_account_migrate_unscoped_layout
    test -d "$__codex_account_accounts_home"; or return 0

    for file in "$__codex_account_accounts_home"/*.auth.json
        test -f "$file"; or continue
        string match -q '*-backup.auth.json' -- "$file"; and continue
        set -l name (basename -- "$file" .auth.json)
        set -l dest (__codex_account_saved_path "$name")
        if not test -f "$dest"
            mv "$file" "$dest"
            chmod 600 "$dest" 2>/dev/null; or true
        end
    end

    for dir in "$__codex_account_accounts_home"/*
        test -d "$dir"; or continue
        set -l name (basename -- "$dir")
        if test "$name" = codex; or test "$name" = pi; or test "$name" = .legacy
            continue
        end

        if test -f "$dir/codex.auth.json"
            set -l dest (__codex_account_saved_path "$name")
            if not test -f "$dest"
                mv "$dir/codex.auth.json" "$dest"
                chmod 600 "$dest" 2>/dev/null; or true
            end
        end
        if test -f "$dir/pi.openai-codex.json"
            set -l dest (__codex_account_saved_path "$name")
            if not test -f "$dest"
                mv "$dir/pi.openai-codex.json" "$dest"
                chmod 600 "$dest" 2>/dev/null; or true
            end
        end
        rmdir "$dir" 2>/dev/null; or true
    end
end

function __codex_account_validate_account_name
    set -l account "$argv[1]"

    if test -z "$account"; or string match -q '*/*' -- "$account"; or string match -q '*..*' -- "$account"
        __codex_account_die "Invalid account name '$account'."
        return 1
    end

    if string match -rq '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}(\.[A-Za-z][A-Za-z0-9]*)?$' -- "$account"
        return 0
    end

    if not string match -rq '^[A-Za-z0-9][A-Za-z0-9._-]*$' -- "$account"
        __codex_account_die "Invalid account name '$account'. Use an email, or letters, numbers, dots, dashes, or underscores."
        return 1
    end

    if string match -q '*-backup' -- "$account"
        __codex_account_die "Account names cannot end with '-backup'."
        return 1
    end
end

function __codex_account_normalize_account_name
    set -l account "$argv[1]"
    if string match -q '*@*' -- "$account"
        string lower -- "$account"
        return
    end
    printf '%s\n' "$account"
end

function __codex_account_set_current_account
    set -l account "$argv[1]"
    set -l file (__codex_account_current_file)
    printf '%s\n' "$account" >"$file"
    chmod 600 "$file" 2>/dev/null; or true
end

function __codex_account_parse_args
    set -g __codex_account_opt_agent
    set -g __codex_account_opt_name
    set -g __codex_account_opt_device 0
    set -g __codex_account_opt_json 0
    set -g __codex_account_opt_all 0
    set -g __codex_account_opt_positionals

    set -l i 1
    while test $i -le (count $argv)
        set -l arg "$argv[$i]"
        switch "$arg"
            case -a --agent --from
                set i (math $i + 1)
                if test $i -gt (count $argv)
                    __codex_account_die "Missing value for $arg."
                    return 1
                end
                set -l normalized (__codex_account_normalize_agent "$argv[$i]")
                if test $pipestatus[1] -ne 0
                    return 1
                end
                set __codex_account_opt_agent "$normalized"
            case -n --name
                set i (math $i + 1)
                if test $i -gt (count $argv)
                    __codex_account_die "Missing value for $arg."
                    return 1
                end
                set __codex_account_opt_name "$argv[$i]"
            case --codex
                set __codex_account_opt_agent codex
            case --pi --from-pi
                set __codex_account_opt_agent pi
            case --opencode --from-opencode
                set __codex_account_opt_agent opencode
            case --device --device-auth
                set __codex_account_opt_device 1
            case --json
                set __codex_account_opt_json 1
            case --all
                set __codex_account_opt_all 1
            case -h --help
                return 2
            case --
                set i (math $i + 1)
                if test $i -le (count $argv)
                    set __codex_account_opt_positionals $argv[$i..]
                end
                return 0
            case '-*'
                __codex_account_die "Unknown option '$arg'."
                return 1
            case '*'
                set -a __codex_account_opt_positionals "$arg"
        end
        set i (math $i + 1)
    end
end

function __codex_account_resolved_name
    set -l name "$__codex_account_opt_name"
    if test -z "$name"; and test (count $__codex_account_opt_positionals) -ge 1
        set name "$__codex_account_opt_positionals[1]"
        set -e __codex_account_opt_positionals[1]
    end
    if test (count $__codex_account_opt_positionals) -gt 0
        __codex_account_die "Unexpected argument '$__codex_account_opt_positionals[1]'."
        return 1
    end
    if test -z "$name"
        return 0
    end
    set name (__codex_account_normalize_account_name "$name")
    __codex_account_validate_account_name "$name"; or return 1
    printf '%s\n' "$name"
end

function __codex_account_command_list
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program list"
            return 1
        case 1
            return 1
    end
    if test (count $__codex_account_opt_positionals) -gt 0
        __codex_account_die "Usage: $__codex_account_program list"
        return 1
    end

    __codex_account_ensure_dirs
    or return 1
    __codex_account_py_store list-accounts
end

function __codex_account_command_current
    if test (count $argv) -gt 0
        __codex_account_die "Usage: $__codex_account_program current"
        return 1
    end
    __codex_account_ensure_dirs
    or return 1
    __codex_account_py_store current-grants
end

function __codex_account_command_save
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program save [-a|--from AGENT] [-n|--name NAME]"
            return 1
        case 1
            return 1
    end
    set -l name (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end

    __codex_account_ensure_dirs
    or return 1

    set -l py_args save-live
    if test -n "$name"
        set -a py_args --name "$name"
    end
    if test -n "$__codex_account_opt_agent"
        set -a py_args --from "$__codex_account_opt_agent"
    else if test -z "$name"
        set -a py_args --from both
    else
        set -a py_args --from pi
    end
    __codex_account_py_store $py_args
    or return 1
    if test -n "$name"
        __codex_account_set_current_account "$name"
    end
end

function __codex_account_command_switch
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program switch [-n|--name] NAME"
            return 1
        case 1
            return 1
    end

    set -l target (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end
    if test -z "$target"
        __codex_account_die "Usage: $__codex_account_program switch [-n|--name] NAME"
        return 1
    end

    __codex_account_ensure_dirs
    or return 1
    __codex_account_py_store switch-grant --name "$target"
    or return 1
    __codex_account_set_current_account "$target"
end

function __codex_account_command_login
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program login [-a|--agent AGENT] [--device] [-n|--name NAME]"
            return 1
        case 1
            return 1
    end
    if test -z "$__codex_account_opt_agent"
        set __codex_account_opt_agent pi
    end
    set -l agent "$__codex_account_opt_agent"
    set -l name (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end

    __codex_account_ensure_dirs
    or return 1

    if test "$agent" = pi
        __codex_account_login_pi "$name"
        return
    end
    __codex_account_login_codex "$name"
end

function __codex_account_login_codex
    set -l name "$argv[1]"

    if not type -q codex
        __codex_account_die "'codex' is not on PATH."
        return 1
    end

    __codex_account_py_store snapshot-lives

    set -l hid_live 0
    if __codex_account_hide_live_codex
        set hid_live 1
        __codex_account_note 'Hid the current Codex login so a new login will not revoke it.'
    end

    if test -n "$name"
        __codex_account_note "Starting Codex CLI login for '$name'."
    else
        __codex_account_note 'Starting Codex CLI login. The slot will be named from the ChatGPT email.'
    end
    if test $__codex_account_opt_device -eq 1
        command codex login --device-auth
    else
        command codex login
    end
    if test $status -ne 0
        if test $hid_live -eq 1
            __codex_account_unhide_live_codex
            __codex_account_note 'Login failed; restored the previous Codex login.'
        end
        return 1
    end

    rm -f (__codex_account_codex_stash_path)
    __codex_account_py write-both --force --from codex --codex-live "$__codex_account_codex_auth_file" --pi-live "$__codex_account_pi_auth_file" --opencode-live "$__codex_account_opencode_auth_file" >/dev/null
    or return 1
    set -l py_args save-live --from codex
    if test -n "$name"
        set -a py_args --name "$name"
    end
    __codex_account_py_store $py_args
    or return 1
    if test -n "$name"
        __codex_account_set_current_account "$name"
    end
    __codex_account_note 'Wrote the same grant to Pi and OpenCode. Restart Pi/Codex/OpenCode if they are already running.'
end

function __codex_account_login_pi
    set -l name "$argv[1]"

    __codex_account_py_store snapshot-lives
    mkdir -p "$__codex_account_pi_home"

    if test -n "$name"
        __codex_account_note "Starting Pi openai-codex login for '$name'."
    else
        __codex_account_note 'Starting Pi openai-codex login. The slot will be named from the ChatGPT email.'
    end

    if test $__codex_account_opt_device -eq 1
        __codex_account_py login-pi --device "$__codex_account_pi_auth_file"
    else
        __codex_account_py login-pi "$__codex_account_pi_auth_file"
    end
    or return 1

    __codex_account_py write-both --force --from pi --codex-live "$__codex_account_codex_auth_file" --pi-live "$__codex_account_pi_auth_file" --opencode-live "$__codex_account_opencode_auth_file" >/dev/null
    or return 1
    set -l py_args save-live --from pi
    if test -n "$name"
        set -a py_args --name "$name"
    end
    __codex_account_py_store $py_args
    or return 1
    if test -n "$name"
        __codex_account_set_current_account "$name"
    end
    __codex_account_note 'Wrote the same grant to Codex and OpenCode. Restart Pi/Codex/OpenCode if they are already running.'
end

function __codex_account_command_sync
    if test (count $argv) -gt 0
        __codex_account_die "Usage: $__codex_account_program sync"
        return 1
    end
    __codex_account_ensure_dirs
    or return 1
    __codex_account_py_store sync
end

function __codex_account_command_refresh
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program refresh [-n|--name NAME]"
            return 1
        case 1
            return 1
    end
    set -l name (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end
    __codex_account_ensure_dirs
    or return 1
    if test -n "$name"
        __codex_account_py_store refresh --name "$name"
    else
        __codex_account_py_store refresh
    end
end

function __codex_account_command_rm
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program rm [-n|--name] NAME"
            return 1
        case 1
            return 1
    end

    set -l account (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end
    if test -z "$account"
        __codex_account_die "Usage: $__codex_account_program rm [-n|--name] NAME"
        return 1
    end

    __codex_account_ensure_dirs
    or return 1

    set -l account (__codex_account_py_store resolve-name --name "$account")
    or return 1
    set -l file (__codex_account_saved_path "$account")
    rm -f "$file"

    set -l recorded_file (__codex_account_current_file)
    if test -f "$recorded_file"
        set -l recorded (string collect <"$recorded_file" | string trim)
        if test "$recorded" = "$account"
            rm -f "$recorded_file"
        end
    end

    __codex_account_note "Removed saved account '$account'."
end

function __codex_account_command_usage
    __codex_account_parse_args $argv
    switch $status
        case 2
            __codex_account_die "Usage: $__codex_account_program usage [-a|--agent AGENT] [-n|--name NAME] [--json]"
            return 1
        case 1
            return 1
    end

    set -l name (__codex_account_resolved_name)
    if test $pipestatus[1] -ne 0
        return 1
    end
    if test -n "$name"; and test $__codex_account_opt_all -eq 1
        __codex_account_die "Use either --all or -n/--name, not both."
        return 1
    end

    __codex_account_ensure_dirs
    or return 1

    set -l py_args usage-report --accounts-home "$__codex_account_accounts_home" --codex-live "$__codex_account_codex_auth_file" --pi-live "$__codex_account_pi_auth_file" --opencode-live "$__codex_account_opencode_auth_file"
    if test -n "$__codex_account_opt_agent"
        set -a py_args --agent "$__codex_account_opt_agent"
    end
    if test -n "$name"
        set -a py_args --name "$name"
    end
    if test $__codex_account_opt_all -eq 1
        set -a py_args --all
    end
    if test $__codex_account_opt_json -eq 1
        set -a py_args --json
    end
    __codex_account_py $py_args
end

function codex-account --description 'Save and switch one ChatGPT login for Pi, Codex, and OpenCode'
    __codex_account_init_vars

    if not type -q python3
        __codex_account_die 'python3 is required.'
        return 1
    end

    set -l command help
    if test (count $argv) -gt 0
        set command "$argv[1]"
        set -e argv[1]
    end

    switch "$command"
        case list
            __codex_account_command_list $argv
        case current status
            __codex_account_command_current $argv
        case save
            __codex_account_command_save $argv
        case switch use
            __codex_account_command_switch $argv
        case login
            __codex_account_command_login $argv
        case sync
            __codex_account_command_sync $argv
        case refresh
            __codex_account_command_refresh $argv
        case usage limits quota
            __codex_account_command_usage $argv
        case rm remove delete
            __codex_account_command_rm $argv
        case help -h --help
            __codex_account_usage
        case '*'
            __codex_account_die "Unknown command '$command'. See '$__codex_account_program help'."
            return 1
    end
end
