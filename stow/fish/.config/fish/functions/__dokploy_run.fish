function __dokploy_run --description "Run dokploy against the instance in ~/.config/dokploy/<name>.env"
    set -l env_file ~/.config/dokploy/$argv[1].env
    if not test -r $env_file
        echo "Missing $env_file (needs DOKPLOY_URL and DOKPLOY_API_KEY)" >&2
        return 1
    end
    set -l vars (string match -rv '^\s*(#|$)' <$env_file)
    env $vars dokploy $argv[2..]
end
