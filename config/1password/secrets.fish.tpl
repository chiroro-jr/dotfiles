# Generated from 1Password by scripts/config/restore-shell-secrets.sh.
# Do not edit this generated file; update the 1Password item instead.
set -gx OPENCODE_API_KEY "{{ op://__VAULT__/__ITEM__/OPENCODE_API_KEY }}"
set -gx NEURALWATT_API_KEY "{{ op://__VAULT__/__ITEM__/NEURALWATT_API_KEY }}"
set -gx CLOUDFLARE_TUNNEL_TOKEN "{{ op://__VAULT__/__ITEM__/CLOUDFLARE_TUNNEL_TOKEN }}"
set -e GITHUB_TOKEN
set -gx GITHUB_RELEASES_TOKEN "{{ op://__VAULT__/__ITEM__/GITHUB_RELEASES_TOKEN }}"
