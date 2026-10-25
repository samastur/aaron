#!/bin/zsh
# Builds Aaron (Release) and installs it as /Applications/Aaron.app. An
# older copy is moved to the Trash. Afterwards, install the command with
# Aaron ▸ Install Command Line Tool….
set -eu
ROOT=${0:A:h:h}
BUILD=$ROOT/build/Release
TARGET=/Applications/Aaron.app

(cd $ROOT/App && xcodegen generate -q && xcodebuild -project Aaron.xcodeproj -scheme Aaron \
  -configuration Release -derivedDataPath $BUILD build -quiet)
APP=$BUILD/Build/Products/Release/Aaron.app
[[ -d $APP ]] || { print -u2 "install: build produced no $APP"; exit 1 }

running() { [[ $(osascript -e 'application id "net.gaivo.Aaron" is running') == true ]] }
if running; then
  read -q "?Aaron is running. Quit it and replace it? [y/N] " || { print; print "Not installed."; exit 1 }
  print
  osascript -e 'tell application id "net.gaivo.Aaron" to quit'
  for i in {1..50}; do running || break; sleep 0.2; done
fi

if [[ -e $TARGET ]]; then
  mv $TARGET "$HOME/.Trash/Aaron $(date +%Y-%m-%d\ %H.%M.%S).app"
fi
ditto $APP $TARGET
print "Installed $TARGET."
print "To use the aaron command, open Aaron and choose Aaron ▸ Install Command Line Tool…."
