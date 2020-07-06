#!/bin/bash

# Script repo: https://github.com/SebastianSimon/firefox-selection-fix
# See https://superuser.com/a/1559926/751213 for detailed explanation.

return_wd="$PWD"
description='The Firefox Selection Fix script disables the broken clickSelectsAll behavior of Firefox. Make sure Firefox is up-to-date and closed'
firefox_dir=$(whereis firefox | cut -d ' ' -f 2)
fallback_firefox_dir='/usr/lib/firefox' # Fallback path: put your Firefox install path here. The install path includes the `firefox` binary and a `browser` directory.

function require_root(){
  if [[ $(id -u) -ne 0 ]]; then
    sudo FIXFX_SUPPRESS_DESCRIPTION=true "${BASH_SOURCE[0]}"
    
    exit $?
  fi
  
  fix_firefox
}

function check_root_required(){
  if [[ $(id -u) -eq 0 ]]; then
    echo 'already_root'
    
    return
  fi
  
  for path in "$firefox_dir/browser" "$firefox_dir/browser/omni.ja" '/tmp'; do
    if [[ ! -w "$path" ]]; then
      echo "$path"
      
      return
    fi
  done
}

function check_firefox_path(){
  if [[ ! -f "$firefox_dir/browser/omni.ja" ]]; then
    firefox_dir="$fallback_firefox_dir"
  fi
  
  if [[ ! -f "$firefox_dir/browser/omni.ja" ]]; then
    echo "Error: Firefox install path not found in '$firefox_dir'." >&2
    
    return 1
  fi
  
  return 0
}

function fix_firefox(){
  create_backup='y'
  restore_backup=''
  
  if [[ -f /tmp/omni.ja~ ]]; then
    read -p 'Create backup of omni.ja before applying the fix? This overwrites the old backup! [y/N] ' -r create_backup
  fi
  
  if [[ "$create_backup" =~ ^[Yy]$ ]]; then
    echo "Copying '$firefox_dir/browser/omni.ja' to '/tmp/omni.ja~'."
    cp -p "$firefox_dir/browser/omni.ja" /tmp/omni.ja~
  fi
  
  echo "Fixing Firefox: '$firefox_dir'."
  echo
  cd /tmp || exit
  mkdir omni
  unzip -q "$firefox_dir/browser/omni.ja" -d omni
  sed -i 's/this\._preventClickSelectsAll = this\.focused;/this._preventClickSelectsAll = true;/' omni/modules/UrlbarInput.jsm
  sed -i 's/this\._preventClickSelectsAll = this\._textbox\.focused;/this._preventClickSelectsAll = true;/' omni/chrome/browser/content/browser/search/searchbar.js
  cd omni || exit
  zip -qr9XD omni.ja ./*
  cd ..
  mv omni/omni.ja "$firefox_dir/browser/omni.ja" || exit
  chown --reference=omni.ja~ "$firefox_dir/browser/omni.ja"
  chmod --reference=omni.ja~ "$firefox_dir/browser/omni.ja"
  rm -r omni
  touch "$firefox_dir/browser/.purgecaches"
  cd "$return_wd" || exit
  echo
  echo 'Your Firefox should now be able to run with an improved user experience! Start Firefox and try it out.'
  read -p 'Press [Enter] to exit. If Firefox does not run properly, restore the backup by pressing [r], then [Enter]. ' -r restore_backup
  
  if [[ "$restore_backup" =~ [Rr] ]]; then
    echo "Copying '/tmp/omni.ja~' to '$firefox_dir/browser/omni.ja'."
    cp -p /tmp/omni.ja~ "$firefox_dir/browser/omni.ja"
    touch "$firefox_dir/browser/.purgecaches"
  else
    echo 'You can restore the backup later on by typing these two commands:'
    echo -e "\033[0;40;96mcp -p /tmp/omni.ja~ $firefox_dir/browser/omni.ja"
    echo -e "touch $firefox_dir/browser/.purgecaches\033[0m"
    echo "You can also copy the file '/tmp/omni.ja~' to another backup location."
  fi
  
  bash
}

check_firefox_path || exit $?

if [[ -f "$firefox_dir/browser/.purgecaches" ]]; then
  echo "Error: You need to start and close Firefox again to apply the changes before running this script." >&2
  
  exit 1
fi

root_required_reason="$(check_root_required)"

if [[ ! "$FIXFX_SUPPRESS_DESCRIPTION" ]]; then
  if [[ "$root_required_reason" && $(id -u) -ne 0 ]]; then
    echo "$description."
  else
    read -p "$description, then press [Enter] to continue. "
  fi
fi

if [[ "$root_required_reason" ]]; then
  if [[ "$root_required_reason" != 'already_root' ]]; then
    echo "Continue as root: write access to '$root_required_reason' is required."
  fi
  
  require_root
else
  fix_firefox
fi
