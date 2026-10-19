function dokploy-live --description "Run dokploy against the live instance"
    set_color --bold red >&2
    echo "LIVE: apps.mykargolink.com" >&2
    set_color normal >&2
    __dokploy_run live $argv
end
