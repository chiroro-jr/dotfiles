if type -q mise
    mise activate fish | source
end

if type -q starship
    starship init fish | source
end

if type -q zoxide
    zoxide init fish | source
end

if type -q try
    try init fish ~/Work/tries | source
end

if type -q fzf
    fzf --fish | source
end
