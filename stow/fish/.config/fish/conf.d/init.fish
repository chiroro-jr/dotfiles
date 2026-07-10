if type -q mise
    mise activate fish | source
end

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish | source
end

function try
    set script_path '/usr/bin/try'
    # Check if first argument is a known command
    switch $argv[1]
        case clone worktree init
            set cmd (/usr/bin/env ruby $script_path --path "/home/dennis/Work/tries" $argv 2>/dev/tty)
        case '*'
            set cmd (/usr/bin/env ruby $script_path cd --path "/home/dennis/Work/tries" $argv 2>/dev/tty)
    end
    set rc $status
    if test $rc -eq 0
        if string match -q "* && *" "$cmd"
            eval $cmd
        else
            printf %s $cmd
        end
    else
        printf %s $cmd
    end
end

if type -q fzf
    fzf --fish | source
end
