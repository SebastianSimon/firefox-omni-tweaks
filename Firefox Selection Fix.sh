#!/bin/bash

# Script repo: https://github.com/SebastianSimon/firefox-selection-fix
# See https://superuser.com/a/1559926/751213 for an explanation.

firefox_dir=$(whereis firefox | cut -d ' ' -f 2)

if [[ ! -f $firefox_dir/browser/omni.ja ]]; then
  firefox_dir='/usr/lib/firefox' # Fallback path: put your Firefox install path here. The install path includes the `firefox` binary and a `browser` directory.
fi

if [[ ! -f $firefox_dir/browser/omni.ja ]]; then
  echo "Error: Firefox install path not found in '$firefox_dir'." >&2
  exit 1
fi

if [[ $(id -u) -ne 0 ]]; then
  echo 'The Firefox Selection Fix script disables the broken clickSelectsAll behavior of Firefox. Make sure Firefox is up-to-date and closed.'
  
  create_backup='y'
  
  if [[ -f /tmp/omni.ja~ ]]; then
    read -p 'Create backup of omni.ja before applying the fix? This overwrites the old backup! [y/N] ' -r create_backup
  fi
  
  if [[ "$create_backup" =~ ^[Yy]$ ]]; then
    echo "Copying '$firefox_dir/browser/omni.ja' to '/tmp/omni.ja~'."
    cp $firefox_dir/browser/omni.ja /tmp/omni.ja~
  fi
  
  echo
  echo "Fixing Firefox: '$firefox_dir'."
  
  sudo "$BASH_SOURCE" $(printf '%q ' "$@")
  
  exit $?
fi

cd /tmp
mkdir omni
unzip -q $firefox_dir/browser/omni.ja -d omni
sed -i 's/this\._preventClickSelectsAll = this\.focused;/this._preventClickSelectsAll = true;/' omni/modules/UrlbarInput.jsm
sed -i 's/this\._preventClickSelectsAll = this\._textbox\.focused;/this._preventClickSelectsAll = true;/' omni/chrome/browser/content/browser/search/searchbar.js
cd omni
zip -qr9XD omni.ja *
cd ..
mv omni/omni.ja $firefox_dir/browser/omni.ja
chown --reference=omni.ja~ $firefox_dir/browser/omni.ja
chmod --reference=omni.ja~ $firefox_dir/browser/omni.ja
rm -r omni
echo 'Your Firefox should now be able to run with an improved user experience!'

bash
