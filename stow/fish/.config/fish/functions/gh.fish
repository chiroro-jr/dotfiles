function gh --description 'Run GitHub CLI without the globally exported GITHUB_TOKEN'
    env -u GITHUB_TOKEN gh $argv
end
