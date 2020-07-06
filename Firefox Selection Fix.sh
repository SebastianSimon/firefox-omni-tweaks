#!/bin/bash

# Script repo: https://github.com/SebastianSimon/firefox-selection-fix
# See https://superuser.com/a/1559926/751213 for detailed explanation.

return_wd="$PWD"
declare root_required
#root_required=true # Uncomment this, if root is required due to file permissions.
description='The Firefox Selection Fix script disables the broken clickSelectsAll behavior of Firefox. Make sure Firefox is up-to-date and closed'

function require_root(){
  if [[ $(id -u) -ne 0 ]]; then
    sudo FIXFX_SUPPRESS_DESCRIPTION=true "${BASH_SOURCE[0]}"
    
    exit $?
  fi
  
  fix_firefox
}

function fix_firefox(){
  firefox_dir=$(whereis firefox | cut -d ' ' -f 2)
  create_backup='y'
  restore_backup=''

  if [[ ! -f "$firefox_dir/browser/omni.ja" ]]; then
    firefox_dir='/usr/lib/firefox' # Fallback path: put your Firefox install path here. The install path includes the `firefox` binary and a `browser` directory.
  fi

  if [[ ! -f "$firefox_dir/browser/omni.ja" ]]; then
    echo "Error: Firefox install path not found in '$firefox_dir'." >&2
    exit 1
  fi

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

if [[ ! "$FIXFX_SUPPRESS_DESCRIPTION" ]]; then
  if [[ "$root_required" = 'true' && $(id -u) -ne 0 ]]; then
    echo "$description."
  else
    read -p "$description, then press [Enter] to continue. "
  fi
fi

if [[ "$root_required" = 'true' ]]; then
  require_root
else
  fix_firefox
fi
