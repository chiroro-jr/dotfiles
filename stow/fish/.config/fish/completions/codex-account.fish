function __codex_account_complete_root
    set -l dir "$HOME/.codex/.codex-account/accounts"
    if set -q CODEX_ACCOUNTS_HOME
        set dir "$CODEX_ACCOUNTS_HOME"
    else if set -q CODEX_ACCOUNT_DIR
        set dir "$CODEX_ACCOUNT_DIR/accounts"
    else if set -q CODEX_HOME
        set dir "$CODEX_HOME/.codex-account/accounts"
    end
    printf '%s\n' "$dir"
end

function __codex_account_complete_names
    set -l dir (__codex_account_complete_root)
    test -d "$dir"; or return
    for file in "$dir"/*.json
        test -f "$file"; or continue
        basename -- "$file" .json
    end
end

complete -c codex-account -f
complete -c codex-account -n '__fish_use_subcommand' -a 'list' -d 'List saved ChatGPT accounts'
complete -c codex-account -n '__fish_use_subcommand' -a 'current' -d 'Show live Pi, Codex, OpenCode, and Zed logins'
complete -c codex-account -n '__fish_use_subcommand' -a 'save' -d 'Save live tokens to the shared store'
complete -c codex-account -n '__fish_use_subcommand' -a 'switch' -d 'Put a saved grant on Pi, Codex, OpenCode, and Zed'
complete -c codex-account -n '__fish_use_subcommand' -a 'login' -d 'Log in via Pi and write the grant to Codex, OpenCode, and Zed'
complete -c codex-account -n '__fish_use_subcommand' -a 'sync' -d 'Copy the newer shared grant to all tools'
complete -c codex-account -n '__fish_use_subcommand' -a 'refresh' -d 'Rotate tokens and write them back'
complete -c codex-account -n '__fish_use_subcommand' -a 'usage' -d 'Show ChatGPT Codex plan usage'
complete -c codex-account -n '__fish_use_subcommand' -a 'rm' -d 'Delete a saved account'
complete -c codex-account -n '__fish_use_subcommand' -a 'help' -d 'Show help'

complete -c codex-account -n '__fish_seen_subcommand_from login' -s a -l agent -x -a 'pi codex' -d 'Login UI to use'
complete -c codex-account -n '__fish_seen_subcommand_from save usage limits quota' -s a -l agent -x -a 'codex pi opencode zed' -d 'Live login to read'
complete -c codex-account -n '__fish_seen_subcommand_from save' -l from -x -a 'codex pi opencode zed' -d 'Live login to snapshot'
complete -c codex-account -n '__fish_seen_subcommand_from save switch rm use login usage limits quota refresh' -s n -l name -x -a '(__codex_account_complete_names)' -d 'Account name'
complete -c codex-account -n '__fish_seen_subcommand_from save' -l codex -d 'Alias for --from codex'
complete -c codex-account -n '__fish_seen_subcommand_from save' -l pi -d 'Alias for --from pi'
complete -c codex-account -n '__fish_seen_subcommand_from save' -l opencode -d 'Alias for --from opencode'
complete -c codex-account -n '__fish_seen_subcommand_from save' -l zed -d 'Alias for --from zed'
complete -c codex-account -n '__fish_seen_subcommand_from switch rm use usage refresh' -a '(__codex_account_complete_names)'
complete -c codex-account -n '__fish_seen_subcommand_from login' -l device -d 'Use device-code login'
complete -c codex-account -n '__fish_seen_subcommand_from usage limits quota' -l json -d 'Print JSON'
