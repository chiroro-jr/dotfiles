if status is-interactive
    # Commands to run in interactive sessions can go here
end

fish_add_path "$HOME/.local/bin"

set -gx PNPM_HOME "$HOME/.local/share/pnpm"
fish_add_path "$PNPM_HOME"

fish_add_path "$HOME/.config/composer/vendor/bin"

# pnpm
set -gx PNPM_HOME "/home/chiroro/.local/share/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end


# User-local binaries
set -gx PATH "/home/chiroro/.local/bin" $PATH
