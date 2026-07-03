#!/bin/bash
# Reinstall XVim for Xcode
# Run this once after upgrade Xcode
# Usage: ./reinstall_xvim.sh

# Update XVim2 sources
cd XVim2
git pull

# sign Xcode
sudo codesign -f -s XcodeSigner /Applications/Xcode.app

# make & install XVim2
make
cd -
