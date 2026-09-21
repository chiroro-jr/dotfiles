# Editor used by CLI
set -x SUDO_EDITOR $EDITOR
set -x BAT_THEME ansi
# API keys and other credentials belong in secrets.fish.

# Android SDK
set -gx ANDROID_HOME "$HOME/Android/Sdk"
fish_add_path "$ANDROID_HOME/emulator"
fish_add_path "$ANDROID_HOME/platform-tools"
set -gx ANDROID_AVD_HOME "$HOME/.config/.android/avd"
set -gx FFF_ENABLE_HOME_SCAN 0


# Chrome for Flutter web
set -gx CHROME_EXECUTABLE /usr/bin/google-chrome-stable

# Bun global packages
fish_add_path "$HOME/.cache/.bun/bin"
