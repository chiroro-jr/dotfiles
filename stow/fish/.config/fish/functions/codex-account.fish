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

    set -g __codex_account_dir "$__codex_account_codex_home/.codex-account"
    if set -q CODEX_ACCOUNT_DIR
        set __codex_account_dir "$CODEX_ACCOUNT_DIR"
    end

    set -g __codex_account_accounts_home "$__codex_account_dir/accounts"
    if set -q CODEX_ACCOUNTS_HOME
        set __codex_account_accounts_home "$CODEX_ACCOUNTS_HOME"
    end

    set -g __codex_account_state_file "$__codex_account_dir/.current-account"
    if set -q CODEX_CURRENT_ACCOUNT_FILE
        set __codex_account_state_file "$CODEX_CURRENT_ACCOUNT_FILE"
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
        "$__codex_account_program - switch saved Codex CLI and Pi Codex subscription accounts" \
        '' \
        'Usage:' \
        "  $__codex_account_program help" \
        "  $__codex_account_program <account>" \
        "  $__codex_account_program list" \
        "  $__codex_account_program current" \
        "  $__codex_account_program save <account>" \
        "  $__codex_account_program switch <account>" \
        '' \
        'Commands:' \
        '  list' \
        "      List saved account profiles from $__codex_account_accounts_home." \
        "      '*' marks the profile matching the live Codex CLI auth." \
        "      '~' marks the recorded current profile when live auth differs." \
        '' \
        '  current' \
        '      Show the active profile when it can be detected.' \
        '' \
        '  save <account>' \
        "      Save current $__codex_account_codex_auth_file and, if present," \
        "      $__codex_account_pi_auth_file into the named profile." \
        '' \
        '  switch <account>' \
        '      Back up current live auth files, then restore the named profile.' \
        '' \
        'Examples:' \
        "  $__codex_account_program save personal" \
        "  $__codex_account_program switch work" \
        "  $__codex_account_program personal" \
        '' \
        'Storage:' \
        "  $__codex_account_accounts_home/<account>/codex.auth.json" \
        "  $__codex_account_accounts_home/<account>/pi.auth.json" \
        '' \
        'Notes:' \
        '  - This swaps auth only; it does not touch other ~/.codex or ~/.pi files.' \
        '  - Pi auth is saved/switched when ~/.pi/agent/auth.json exists in the profile.' \
        '  - After switching, restart Codex/Pi sessions that are already running.'
end

function __codex_account_ensure_dirs
    mkdir -p "$__codex_account_codex_home" "$__codex_account_dir" "$__codex_account_accounts_home"
    chmod 700 "$__codex_account_dir" 2>/dev/null; or true
    chmod 700 "$__codex_account_accounts_home" 2>/dev/null; or true
end

function __codex_account_validate_account_name
    set -l account "$argv[1]"

    if not string match -rq '^[A-Za-z0-9][A-Za-z0-9._-]*$' -- "$account"
        __codex_account_die "Invalid account name '$account'. Use letters, numbers, dots, dashes, or underscores."
        return 1
    end

    if string match -q '*-backup' -- "$account"
        __codex_account_die "Account names cannot end with '-backup'."
        return 1
    end
end

function __codex_account_profile_dir
    printf '%s/%s\n' "$__codex_account_accounts_home" "$argv[1]"
end

function __codex_account_codex_saved_path
    printf '%s/codex.auth.json\n' (__codex_account_profile_dir "$argv[1]")
end

function __codex_account_pi_saved_path
    printf '%s/pi.auth.json\n' (__codex_account_profile_dir "$argv[1]")
end

function __codex_account_legacy_codex_saved_path
    printf '%s/%s.auth.json\n' "$__codex_account_accounts_home" "$argv[1]"
end

function __codex_account_codex_backup_path
    printf '%s/codex-backup.auth.json\n' (__codex_account_profile_dir "$argv[1]")
end

function __codex_account_pi_backup_path
    printf '%s/pi-backup.auth.json\n' (__codex_account_profile_dir "$argv[1]")
end

function __codex_account_get_saved_codex_path
    set -l account "$argv[1]"
    set -l profile_path (__codex_account_codex_saved_path "$account")
    if test -f "$profile_path"
        printf '%s\n' "$profile_path"
        return 0
    end

    set -l legacy_path (__codex_account_legacy_codex_saved_path "$account")
    if test -f "$legacy_path"
        printf '%s\n' "$legacy_path"
        return 0
    end

    return 1
end

function __codex_account_set_current_account
    printf '%s\n' "$argv[1]" >"$__codex_account_state_file"
    chmod 600 "$__codex_account_state_file" 2>/dev/null; or true
end

function __codex_account_get_recorded_account
    test -f "$__codex_account_state_file"; or return 1
    set -l account (string collect <"$__codex_account_state_file")
    test -n "$account"; or return 1
    printf '%s\n' "$account"
end

function __codex_account_match_live_account
    test -f "$__codex_account_codex_auth_file"; or return 1

    for dir in "$__codex_account_accounts_home"/*
        test -d "$dir"; or continue
        set -l file "$dir/codex.auth.json"
        test -f "$file"; or continue
        if cmp -s "$__codex_account_codex_auth_file" "$file"
            basename -- "$dir"
            return 0
        end
    end

    # Legacy flat storage from the original single-tool switcher.
    for file in "$__codex_account_accounts_home"/*.auth.json
        test -f "$file"; or continue
        string match -q '*-backup.auth.json' -- "$file"; and continue
        if cmp -s "$__codex_account_codex_auth_file" "$file"
            basename -- "$file" .auth.json
            return 0
        end
    end

    return 1
end

function __codex_account_copy_file_to
    set -l source "$argv[1]"
    set -l destination "$argv[2]"
    mkdir -p (dirname -- "$destination")
    cp "$source" "$destination"
    chmod 600 "$destination" 2>/dev/null; or true
end

function __codex_account_restore_file
    set -l source "$argv[1]"
    set -l destination "$argv[2]"
    mkdir -p (dirname -- "$destination")
    set -l tmp_file (mktemp "$destination.tmp.XXXXXX")
    cp "$source" "$tmp_file"
    chmod 600 "$tmp_file" 2>/dev/null; or true
    mv "$tmp_file" "$destination"
end

function __codex_account_all_accounts
    set -l accounts

    for dir in "$__codex_account_accounts_home"/*
        test -d "$dir"; or continue
        test -f "$dir/codex.auth.json" -o -f "$dir/pi.auth.json"; or continue
        set -a accounts (basename -- "$dir")
    end

    for file in "$__codex_account_accounts_home"/*.auth.json
        test -f "$file"; or continue
        string match -q '*-backup.auth.json' -- "$file"; and continue
        set -l account (basename -- "$file" .auth.json)
        contains -- "$account" $accounts; or set -a accounts "$account"
    end

    printf '%s\n' $accounts | sort
end

function __codex_account_command_list
    __codex_account_ensure_dirs

    set -l matched_current (__codex_account_match_live_account)
    set -l recorded_current (__codex_account_get_recorded_account)
    set -l accounts (__codex_account_all_accounts)

    if test (count $accounts) -eq 0
        __codex_account_note 'No saved Codex account profiles.'
        return 0
    end

    for account in $accounts
        set -l prefix ' '
        if test "$account" = "$matched_current"
            set prefix '*'
        else if test -z "$matched_current"; and test "$account" = "$recorded_current"
            set prefix '~'
        end

        set -l labels
        if test -f (__codex_account_get_saved_codex_path "$account")
            set -a labels codex
        end
        if test -f (__codex_account_pi_saved_path "$account")
            set -a labels pi
        end

        printf '%s %s [%s]\n' "$prefix" "$account" (string join , $labels)
    end

    if test -z "$matched_current"; and test -n "$recorded_current"
        __codex_account_note ''
        __codex_account_note '~ recorded current profile (live Codex CLI auth differs from saved snapshot)'
    end
end

function __codex_account_command_current
    __codex_account_ensure_dirs

    if not test -f "$__codex_account_codex_auth_file"
        __codex_account_note "No active Codex CLI auth file at $__codex_account_codex_auth_file."
        return 0
    end

    set -l matched_current (__codex_account_match_live_account)
    set -l recorded_current (__codex_account_get_recorded_account)

    if test -n "$matched_current"
        __codex_account_note "$matched_current"
    else if test -n "$recorded_current"
        __codex_account_note "$recorded_current (recorded, live Codex CLI auth differs from saved snapshot)"
    else
        __codex_account_note 'Current Codex CLI auth is not linked to a saved profile.'
    end
end

function __codex_account_command_save
    set -l account "$argv[1]"
    if test -z "$account"
        __codex_account_die "Usage: $__codex_account_program save <account>"
        return 1
    end

    __codex_account_validate_account_name "$account"; or return 1
    __codex_account_ensure_dirs

    if not test -f "$__codex_account_codex_auth_file"
        __codex_account_die "No Codex CLI auth file found at $__codex_account_codex_auth_file. Run 'codex login' first."
        return 1
    end

    set -l profile_dir (__codex_account_profile_dir "$account")
    mkdir -p "$profile_dir"
    chmod 700 "$profile_dir" 2>/dev/null; or true

    __codex_account_copy_file_to "$__codex_account_codex_auth_file" (__codex_account_codex_saved_path "$account")
    __codex_account_note "Saved Codex CLI auth as '$account'."

    if test -f "$__codex_account_pi_auth_file"
        __codex_account_copy_file_to "$__codex_account_pi_auth_file" (__codex_account_pi_saved_path "$account")
        __codex_account_note "Saved Pi auth as '$account'."
    else
        __codex_account_note "No Pi auth file at $__codex_account_pi_auth_file; saved Codex CLI auth only."
    end

    __codex_account_set_current_account "$account"
end

function __codex_account_command_switch
    set -l target "$argv[1]"
    if test -z "$target"
        __codex_account_die "Usage: $__codex_account_program switch <account>"
        return 1
    end

    __codex_account_validate_account_name "$target"; or return 1
    __codex_account_ensure_dirs

    set -l target_codex_file (__codex_account_get_saved_codex_path "$target")
    if test -z "$target_codex_file"
        __codex_account_die "Unknown account '$target'. Run '$__codex_account_program save $target' after logging into it."
        return 1
    end

    set -l matched_current (__codex_account_match_live_account)
    set -l recorded_current (__codex_account_get_recorded_account)

    if test "$matched_current" = "$target"
        __codex_account_set_current_account "$target"
        __codex_account_note "Account '$target' is already active for Codex CLI."

        set -l target_pi_file (__codex_account_pi_saved_path "$target")
        if test -f "$target_pi_file"
            __codex_account_restore_file "$target_pi_file" "$__codex_account_pi_auth_file"
            __codex_account_note "Switched Pi to '$target'."
        else
            __codex_account_note "No saved Pi auth for '$target'; left Pi auth unchanged."
        end

        __codex_account_note 'Restart Codex/Pi if they are already running.'
        return 0
    end

    set -l backup_account "$matched_current"
    if test -z "$backup_account"
        set backup_account "$recorded_current"
    end

    if test -n "$backup_account"
        set -l backup_dir (__codex_account_profile_dir "$backup_account")
        mkdir -p "$backup_dir"
        chmod 700 "$backup_dir" 2>/dev/null; or true

        if test -f "$__codex_account_codex_auth_file"
            __codex_account_copy_file_to "$__codex_account_codex_auth_file" (__codex_account_codex_backup_path "$backup_account")
            __codex_account_note "Backed up current Codex CLI auth for '$backup_account'."
        end

        if test -f "$__codex_account_pi_auth_file"
            __codex_account_copy_file_to "$__codex_account_pi_auth_file" (__codex_account_pi_backup_path "$backup_account")
            # Also refresh the saved profile snapshot to preserve OAuth token rotation.
            __codex_account_copy_file_to "$__codex_account_pi_auth_file" (__codex_account_pi_saved_path "$backup_account")
            __codex_account_note "Backed up current Pi auth for '$backup_account'."
        end
    else if test -f "$__codex_account_codex_auth_file" -o -f "$__codex_account_pi_auth_file"
        __codex_account_note 'Current auth is not linked to a saved account, skipping named backup.'
    end

    __codex_account_restore_file "$target_codex_file" "$__codex_account_codex_auth_file"
    __codex_account_note "Switched Codex CLI to '$target'."

    set -l target_pi_file (__codex_account_pi_saved_path "$target")
    if test -f "$target_pi_file"
        __codex_account_restore_file "$target_pi_file" "$__codex_account_pi_auth_file"
        __codex_account_note "Switched Pi to '$target'."
    else
        __codex_account_note "No saved Pi auth for '$target'; left Pi auth unchanged."
    end

    __codex_account_set_current_account "$target"

    __codex_account_note 'Restart Codex/Pi if they are already running.'
end

function codex-account --description 'Switch saved Codex CLI and Pi Codex subscription accounts'
    __codex_account_init_vars

    set -l command help
    if test (count $argv) -gt 0
        set command "$argv[1]"
        set -e argv[1]
    end

    switch "$command"
        case list
            __codex_account_command_list $argv
        case current
            __codex_account_command_current $argv
        case save
            __codex_account_command_save $argv
        case switch
            __codex_account_command_switch $argv
        case help -h --help
            __codex_account_usage
        case '*'
            if test (count $argv) -eq 0
                __codex_account_validate_account_name "$command"; or return 1
                __codex_account_ensure_dirs

                if test -n (__codex_account_get_saved_codex_path "$command")
                    __codex_account_command_switch "$command"
                    return 0
                end

                printf "Unknown account '%s'.\n\n" "$command" >&2
                __codex_account_usage >&2
                return 1
            end

            __codex_account_die "Unknown command '$command'. See '$__codex_account_program help'."
            return 1
    end
end
