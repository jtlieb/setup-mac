# !/bin/bash

set -u

function validate_input {
  local confirm 
  read -p "Continue? (y/n): " confirm

  status="1" 
  if [[ "$confirm" == [yY] || "$confirm" == [yY][eE][sS] ]]; then 
    status="0"
  fi

  echo "$status"
}

## check app takes arguments in the form of
# $app_name, [$custom_existence_check]
function check_app {
  echo "check app called with $# args: $@"
  # custom check provided
  if [[ "$#" -ge 2 ]]; then
    shift
    echo "calling $@"
    "$@" &> /dev/null
  else # fallback to default
    ls /Applications/ | grep "$1" &> /dev/null
  fi

  if [[ $? -eq 0 ]]; then
    return 0
  fi

  return 1
}

## install functions take arguments in the form of
# $url, $app_name, [$existence_check_cmd]
function install_dmg {
  url="$1"
  app="$2"
  shift

  check_app $@
  if [[ $? -eq 0 ]]; then
    echo "$app already exists, skipping install"
    return 1
  fi

  local tempd=$(mktemp -d)
  curl -sL $url > $tempd/pkg.dmg
  listing=$(sudo hdiutil attach $tempd/pkg.dmg | grep Volumes)
  volume=$(echo "$listing" | cut -f 3)

  if [ -e "$volume"/*.app ]; then
    sudo cp -rf "$volume"/*.app /Applications
  elif [ -e "$volume"/*.pkg ]; then
    package=$(ls -1 "$volume" | grep .pkg | head -1)
    sudo installer -pkg "$volume"/"$package" -target /
  fi

  sudo hdiutil detach "$(echo "$listing" | cut -f 1 -d ' ')"
  rm -rf $tempd
}

function install_zip {
  url="$1"
  app="$2"
  shift

  check_app $@
  if [[ $? -eq 0 ]]; then
    echo "$app already exists, skipping install.."
    return 1
  fi

  local tempd=$(mktemp -d)
  curl -sL $url > $tempd/pkg.zip
  sudo unzip -qqa "$tempd/pkg.zip" -d "$tempd"
  app=$(find "$tempd" -name "*.app" -d 1)

  if [ -n "$app" ]; then
    sudo cp -rf "$app" /Applications
    sudo rm -rf $tempd
  else
    echo "no .app file found in pkg at $tempd ... leaving"  
  fi
}

function install_pkg {
  url="$1"
  app="$2"
  shift

  check_app $@
  if [[ $? -eq 0 ]]; then
    echo "$app already exists, skipping install.."
    return 1
  fi

  local tempd=$(mktemp -d)
  curl -sL $url > $tempd/package.pkg
  sudo installer -pkg $tempd/package.pkg -target /
  sudo rm -rf $tempd/package.pkg 
}

function get_repo {
  echo "getting $1 repository.." 
  if [[ -d "$2" ]]; then
    echo "already have $2 repo.. pulling latest"
    cd "$2" && git pull origin master
  else
    git clone $1 $2
  fi
} 

## validate shell is bash
echo "checking default shell"
if [[ "$SHELL" != ["/bin/bash"] ]]; then
  chsh -s /bin/bash
  echo "set bash as default shell"
else
  echo "default shell is already set to bash" 
fi

## setup git
echo "checking git"
git > /dev/null

## generate ssh key for this computer if necessary
echo "check GitHub ssh status"
ssh -T git@github.com > /dev/null

if [[ $? -ne 1 ]]; then
  echo "No valid GitHub ssh key found. Attempting to generate"

  if [[ $(validate_input) == "0" ]]; then
    echo "generating ssh key.."
    read -p "enter GitHub username: " gh_user

    ssh-keygen -t rsa -b 4096 -C "$gh_user"
    eval "$(ssh-agent -s)"
    ssh-add -K ~/.ssh/id_rsa
    id_rsa=$(cat ~/.ssh/id_rsa.pub)

    read -p "enter GitHub PAT: " gh_pat
    read -p "enter key name: " ssh_key_name

    curl -u "$gh_user:$gh_pat" --data "{\"title\":\"$ssh_key_name\",\"key\":\"$id_rsa\"}" https://api.github.com/user/keys
  else
    echo "skipping generating GitHub ssh keys"
  fi
fi

# # get relevant git repos
# mkdir ~/git

# echo "cloning bash_profile"
# get_repo git@github.com:salmaanrizvi/bash_profile.git ~/git/bash_profile

# echo "symlinking bash_profile" 
# ln -is ~/git/bash_profile/.bash_profile ~/.bash_profile
# ln -is ~/git/bash_profile/.profile ~/.profile

# ## install iterm2
# echo "installing iTerm 2"
# install_zip https://iterm2.com/downloads/stable/iTerm2-3_3_9.zip "iTerm"
# if [[ $? -eq 0 ]]; then
#   get_repo git@github.com:salmaanrizvi/iTermSettings.git ~/git/iTermSettings
#   echo "done installing iTerm. please import preferences in General -> Preferences -> Load Preferences. waiting..."
#   open -Wn /Applications/iTerm.app  
# fi

# echo "installing Sublime"
# install_dmg "https://download.sublimetext.com/Sublime%20Text%20Build%203211.dmg" "Sublime"
# if [[ $? -eq 0 ]]; then
#   get_repo git@github.com:salmaanrizvi/SublimeSettings.git ~/git/SublimeSettings
#   sudo ln -is /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl
#   echo "done installing sublime. please install package control. waiting..."
#   open -Wn /Applications/Sublime\ Text.app
#   ln -is ~/git/SublimeSettings/* ~/Library/Application\ Support/Sublime\ Text\ 3/Packages/User
# fi


echo "installing Spectacle"
install_zip https://s3.amazonaws.com/spectacle/downloads/Spectacle+1.2.zip "Spectacle"


echo "installing Slack"
install_dmg "https://slack.com/ssb/download-osx" "Slack"

echo "installing Docker"
install_dmg "https://download.docker.com/mac/stable/Docker.dmg" "Docker"

echo "installing Go"
install_pkg "https://dl.google.com/go/go1.14.2.darwin-amd64.pkg" "Go" "ls /usr/local/go"

which brew
if [[ $? -ne 0 ]]; then
  echo "installing brew"
  bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

# Dev tools
brew install \ 
bat \ 
fd \ 
fzf \ 
helm \ 
hub \ 
jq \ 
kubectl \ 
kubectx \ 
node \ 
ripgrep \ 
tfenv \ 
tig 

# Desktop apps
brew install --cask \ 
1password \ 
1password/tap/1password-cli \ 
brave-browser \ 
intellij-idea-ce \ 
notion \ 
scroll-reverser \ 
spotify \ 
visual-studio-code \ 
warp \ 
zoom

# Tweaking dock
defaults write com.apple.dock orientation right # dock location to right side
defaults write com.apple.Dock autohide-delay -float 0 # show dock instantly
defaults write com.apple.dock autohide-time-modifier -float 0.15 # speed up animation
defaults write com.apple.dock largesize -int 128 # magnify size
defaults write com.apple.dock tilesize -integer 40 # default size
# defaults write com.apple.dock persistent-apps -array-add '{"tile-type"="small-spacer-tile";}' # add spacer

# Insert all changes to dock above this line
killall Dock
