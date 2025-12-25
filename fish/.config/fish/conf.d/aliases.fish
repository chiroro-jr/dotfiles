# File system
if type -q eza
    alias ls='eza -lh --group-directories-first --icons=auto'
    alias lsa='ls -a'
    alias lt='eza --tree --level=2 --long --icons --git'
    alias lta='lt -a'
end

alias ff="fzf --preview 'bat --style=numbers --color=always {}'"

if type -q zoxide
    alias cd="zd"
    function zd
        if test (count $argv) -eq 0
            builtin cd ~
        else if test -d "$argv[1]"
            builtin cd "$argv[1]"
        else
            z $argv && printf "\U000F17A9 " && pwd || echo "Error: Directory not found"
        end
    end
end

function open
    xdg-open $argv >/dev/null 2>&1 &
    disown
end

# Directories
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Tools
alias d='docker'
alias r='rails'

function n
    if test (count $argv) -eq 0
        nvim .
    else
        nvim $argv
    end
end

# Git
alias g='git'
alias gcm='git cm'
alias gcam='git cam'
alias gcad='git cad'
alias gd='git diff'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gu='git pull'
alias gl='git log'
alias gb='git branch'
alias gsw='git switch'
alias gi='git init'
alias gcl='git clone'

# zed
alias zed='zeditor'
