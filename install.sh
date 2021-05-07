#!/bin/bash

set -Ceuxo pipefail

is_mac() {
  [ "$(uname)" == 'Darwin' ]
}

is_linux() {
  [ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]
}

is_wsl2() {
  [[ "$(uname -r)" =~ 'microsoft' ]]
}

is_mt() {
  [ "${TERM_PROGRAM}" = 'Apple_Terminal' ]
}

is_wt() {
  [ -n "${WT_SESSION}" ]
}

install_homedir() {
  local -r homedir_path="$(realpath "${HOME}/homedir")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/homedir/master/install.sh) "${homedir_path}"
}

install_dotfiles() {
  local -r dotfiles_path="$(realpath "${HOME}/share/dotfiles")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/dotfiles/master/install.sh) "${dotfiles_path}"
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
  ((sudo crontab -l 2>/dev/null || echo -n "") ; echo "* * * * * /usr/sbin/hwclock --hctosys") | sort | uniq | sudo crontab -
  sudo service cron start
}

install_mt_settings() {
  # TODO
  :
}

install_wt_settings() {
  local -r wt_settings_path="$(realpath "${HOME}/tmp/wt-settings")"
  bash <(curl -LSs https://raw.githubusercontent.com/ngmy/wt-settings/master/install.sh) "${wt_settings_path}"
}

install_apt_packages() {
  sudo apt update

  # Install the build-essential package, which is required to install Homebrew
  sudo apt -Vy install build-essential

  # Upgrade Vim
  sudo add-apt-repository -y ppa:jonathonf/vim
  sudo apt -Vy upgrade vim
}

install_homebrew_packages() {
  # Install the Homebrew package manager
  # Remove the sudo credential cache to install Homebrew into the home directory
  sudo -K
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  source "${HOME}/.bash_profile"

  # Install Homebrew packages
  brew bundle --global -v

  # Create symbolic links to use java command to run the GCM4ML
  brew link openjdk --force

  # Set up the nodebrew and install the Node.js
  nodebrew setup
  nodebrew install stable
  nodebrew use stable
}

restart_shell() {
  exec -l "${SHELL}"
}

execute_tasks() {
  local -r tasks=("$@")
  local task
  for task in "${tasks[@]}"; do
    eval "${task}"
  done
}

main() {
  local -r mac_tasks=(
    'install_homedir'
    'install_dotfiles'
    'install_terminal_settings_for_mac'
    'install_homebrew_packages'
    'restart_shell'
  )
  local -r wsl2_tasks=(
    'install_homedir'
    'install_dotfiles'
    'install_terminal_settings_for_wsl2'
    'install_apt_packages'
    'install_homebrew_packages'
    'restart_shell'
  )

  if is_mac; then
    execute_tasks "${mac_tasks[@]}"
  elif is_wsl2; then
    execute_tasks "${wsl2_tasks[@]}"
  else
    echo "Your platform ($(uname -a)) is not supported."
    exit 1
  fi
}

main "$@"
