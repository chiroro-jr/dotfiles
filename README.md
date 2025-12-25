# Dotfiles

Personal configuration files for my Linux development environment, managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Structure

```
dotfiles/
├── fish/           # Fish shell configuration
├── git/            # Git configuration
├── vscode/         # VS Code settings
├── vscode-insiders/# VS Code Insiders settings
└── zed/            # Zed editor settings
```

## Installation

Clone the repository and use GNU Stow to symlink configurations:

```bash
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Install all configurations
stow fish git vscode zed

# Or install individually
stow fish
stow git
```

## Configurations

### Fish Shell

Located in `fish/.config/fish/conf.d/`:

- **aliases.fish** - Shell aliases and functions
  - File navigation with `eza` (enhanced `ls`) and `zoxide` (smart `cd`)
  - Git shortcuts (`g`, `gs`, `gd`, `gp`, etc.)
  - Tool shortcuts (`d` for docker, `r` for rails, `n` for nvim)
  - Directory traversal (`..`, `...`, `....`)

- **envs.fish** - Environment variables
  - Editor configuration
  - BAT theme settings

- **functions.fish** - Custom utility functions
  - `img2jpg` - Convert images to optimized JPG
  - `img2jpg-small` - Convert images to web-optimized JPG (max 1080px)
  - `img2png` - Convert images to optimized PNG

- **init.fish** - Tool initializations
  - [mise](https://mise.jdx.dev/) - Dev tool version manager
  - [Starship](https://starship.rs/) - Cross-shell prompt
  - [zoxide](https://github.com/ajeetdsouza/zoxide) - Smarter cd
  - [fzf](https://github.com/junegunn/fzf) - Fuzzy finder

### Git

Located in `git/.config/git/`:

- **config** - Git configuration
  - GPG commit signing enabled
  - VS Code as merge tool and editor
  - Optimized diff settings (histogram algorithm)
  - Auto-setup remote on push
  - Rerere enabled for conflict resolution
  - Branch sorting by commit date

- **template** - Commit message template with emoji suggestions for conventional commits

- **ignore** - Global gitignore patterns

### VS Code / VS Code Insiders

Both share identical configurations:

- **settings.json** - Editor settings
  - Gruvbox Dark Hard theme
  - JetBrainsMono Nerd Font with ligatures
  - Minimal UI (no minimap, single tab, sidebar on right)
  - Biome as default formatter for JS/TS
  - Fish as default terminal
  - TailwindCSS and Emmet configurations

- **keybindings.json** - Custom keyboard shortcuts
  - Panel navigation (`Ctrl+K Ctrl+E/G/D/X`)
  - Split panel management (`Alt+N/H/L/W`)
  - Terminal splits and navigation
  - Line manipulation (`Ctrl+L` duplicate, `Ctrl+J` join)
  - Emmet shortcuts (`Ctrl+M` prefix)
  - Multi-cursor enhancements

### Zed

Located in `zed/.config/zed/`:

- **settings.json** - Editor settings
  - JetBrainsMono Nerd Font
  - KTRZ Monokai (dark) / One Light themes
  - Copilot edit predictions
  - Tab bar hidden, preview tabs disabled
  - MCP context servers configured (context7, shadcn, chrome-devtools, deepwiki)

- **keymap.json** - Custom keybindings
  - Panel toggles matching VS Code (`Ctrl+K Ctrl+E/G`)
  - Line duplication (`Ctrl+L`)
  - Inline AI assist (`Ctrl+I`)
  - Emmet wrap with tag (`Ctrl+M Ctrl+W`)

## Dependencies

These configurations expect the following tools to be installed:

| Tool | Purpose |
|------|---------|
| [fish](https://fishshell.com/) | Shell |
| [eza](https://github.com/eza-community/eza) | Modern ls replacement |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | Smarter cd |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder |
| [bat](https://github.com/sharkdp/bat) | Cat with syntax highlighting |
| [starship](https://starship.rs/) | Shell prompt |
| [mise](https://mise.jdx.dev/) | Dev tool version manager |
| [ImageMagick](https://imagemagick.org/) | Image conversion functions |

### Fonts

- JetBrainsMono Nerd Font
- FiraCode Nerd Font

## License

MIT
