#!/bin/bash

# Script repo: https://github.com/SebastianSimon/firefox-selection-fix
# See https://superuser.com/a/1559926/751213 for an explanation.

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

  echo
  echo "Fixing Firefox: '$firefox_dir'."
  cd /tmp || exit
  mkdir omni
  unzip -q "$firefox_dir/browser/omni.ja" -d omni
  sed -i 's/this\._preventClickSelectsAll = this\.focused;/this._preventClickSelectsAll = true;/' omni/modules/UrlbarInput.jsm
  sed -i 's/this\._preventClickSelectsAll = this\._textbox\.focused;/this._preventClickSelectsAll = true;/' omni/chrome/browser/content/browser/search/searchbar.js
  cd omni || exit
  zip -qr9XD omni.ja ./*
  cd ..
  mv omni/omni.ja "$firefox_dir/browser/omni.ja"
  chown --reference=omni.ja~ "$firefox_dir/browser/omni.ja"
  chmod --reference=omni.ja~ "$firefox_dir/browser/omni.ja"
  rm -r omni
  touch "$firefox_dir/browser/.purgecaches"
  echo 'Your Firefox should now be able to run with an improved user experience!'
  bash
}

if [[ ! "$FIXFX_SUPPRESS_DESCRIPTION" ]]; then
  if [[ "$root_required" = 'true' && $(id -u) -ne 0 ]]; then
    echo "$description."
  else
    read -p "$description, then press Enter to continue. "
  fi
fi

if [[ "$root_required" = 'true' ]]; then
  require_root
else
  fix_firefox
fi
