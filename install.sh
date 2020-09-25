#!/bin/bash
set -Ceuxo pipefail

is_mac() {
  [ "$(uname)" == 'Darwin' ]
}

is_linux() {
  [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]
}

is_wsl2() {
  [ is_linux -a -d '/mnt/c' ]
}

is_mt() {
  [ "${TERM_PROGRAM}" = 'Apple_Terminal' ]
}

is_wt() {
  [ -n "${WT_SESSION}" ]
}

install_homedir() {
  local HOMEDIR_PATH="$(realpath "${HOME}/homedir")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/homedir/master/install.sh) "${HOMEDIR_PATH}"
}

install_dotfiles() {
  local DOTFILES_PATH="$(realpath "${HOME}/share/dotfiles")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/dotfiles/master/install.sh) "${DOTFILES_PATH}"
}

install_terminal_settings_for_mac() {
  if is_mt; then
    install_mt_settings
  fi
}

install_terminal_settings_for_wsl2() {
  if is_wt; then
    install_wt_settings
  fi

  # HACK: Synchronize the system clock with Windows
  #       https://github.com/microsoft/WSL/issues/4245
  ((sudo crontab -l 2>/dev/null || echo -n "") ; echo "* * * * * hwclock --hctosys") | sort | uniq | sudo crontab -
  sudo service cron start
}

install_mt_settings() {
  # TODO
  :
}

install_wt_settings() {
  local WT_SETTINGS_PATH="$(realpath "${HOME}/tmp/wt-settings")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/wt-settings/master/install.sh) "${WT_SETTINGS_PATH}"
}

install_homebrew() {
  # Install the Homebrew package manager
  sudo -K
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  sudo apt-get update
  sudo apt-get -V install build-essential
  source "${HOME}/.bash_profile"

  # Install Homebrew packages
  brew bundle --global -v

  # Install the GCM4ML
  git-credential-manager install
  # Restore the side effect of the "install" command
  git -C "$(dirname "$(readlink "${HOME}/.gitconfig")")" checkout "$(readlink "${HOME}/.gitconfig")"
}

execute_tasks() {
  local TASKS=("$@")
  local task
  for task in "${TASKS[@]}"; do
    eval "${task}"
  done
}

main() {
  local MAC_TASKS=(
    'install_homedir'
    'install_dotfiles'
    'install_terminal_settings_for_mac'
    'install_homebrew'
  )
  local WSL2_TASKS=(
    'install_homedir'
    'install_dotfiles'
    'install_terminal_settings_for_wsl2'
    'install_homebrew'
  )

  if is_mac; then
    execute_tasks "${MAC_TASKS[@]}"
  elif is_wsl2; then
    execute_tasks "${WSL2_TASKS[@]}"
  else
    echo "Your platform ($(uname -a)) is not supported."
    exit 1
  fi
}

main
