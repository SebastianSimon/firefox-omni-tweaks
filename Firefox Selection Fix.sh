#!/bin/bash

# Script repo: https://github.com/SebastianSimon/firefox-selection-fix
# See https://superuser.com/a/1559926/751213 for detailed explanation.

readonly description='The Firefox Selection Fix script disables the broken clickSelectsAll behavior of Firefox. Make sure Firefox is up-to-date and closed'
readonly reason_already_root='already_root'
readonly absolute_bash_source="$([[ "${BASH_SOURCE[0]}" =~ ^/ ]] && echo "${BASH_SOURCE[0]}" || echo "$(pwd)/${BASH_SOURCE[0]}")"
firefox_dir=''
fallback_firefox_dir='/usr/lib/firefox' # Fallback path: put your Firefox install path here. The install path includes the `firefox` binary and a `browser` directory.

function choose_firefox_path(){
  local valid_dirs=()
  local add_fallback_path='yes'
  
  for firefox_dir in "${firefox_dirs[@]}"; do
    if [[ -f "${firefox_dir}/browser/omni.ja" ]]; then
      valid_dirs+=("${firefox_dir}")
    fi
    
    if [[ "${firefox_dir}" -ef "${fallback_firefox_dir}" ]]; then
      add_fallback_path=''
    fi
  done
  
  if [[ "${add_fallback_path}" && -f "${fallback_firefox_dir}/browser/omni.ja" ]]; then
    valid_dirs+=("${fallback_firefox_dir}")
  fi
  
  if [[ "${#valid_dirs[@]}" -eq 0 ]]; then
    echo "Error: Firefox install path not found in the path(s) ${firefox_dirs[*]@Q}." >&2
    
    return 1
  fi
  
  if [[ "${#valid_dirs[@]}" -eq 1 ]]; then
    echo "Firefox install path found in ${valid_dirs[0]@Q}."
    firefox_dir="${valid_dirs[0]}"
    
    return 0
  fi
  
  echo "Multiple Firefox install paths found. Type a number to choose one path:"
  
  select firefox_dir in "${valid_dirs[@]}"; do
    if {
      [ 1 -le "${REPLY}" ] && [ "${REPLY}" -le "${#valid_dirs[@]}" ];
    } 2>/dev/null; then
      echo "Chose option ${REPLY}: ${firefox_dir@Q}."
      
      break
    else
      echo "Number ${REPLY@Q} is not a valid choice."
    fi
  done
  
  return 0
}

function check_root_required(){
  if [[ $(id --user) -eq 0 ]]; then
    echo "${reason_already_root}"
    
    return
  fi
  
  for path in '/tmp' "${firefox_dir}/browser" "${firefox_dir}/browser/omni.ja"; do
    if [[ ! -w "${path}" ]]; then
      echo "${path}"
      
      return
    fi
  done
}

function require_root(){
  if [[ $(id --user) -ne 0 ]]; then
    sudo FIXFX_SUPPRESS_DESCRIPTION=true FIXFX_FIREFOX_PATH="${firefox_dir}" "${absolute_bash_source}"
    
    exit
  fi
  
  fix_firefox
}

function unzip_without_expected_errors(){
  local -r unzip_errors="$(unzip -d /tmp/omni -o -qq -- "${firefox_dir}/browser/omni.ja" 2>&1)"
  local -r expected_errors='^warning.+?\[.*?omni\.ja\]:.+?[1-9][0-9]*.+?extra.+?bytes.+?attempting.+?anyway.+?error.+?\[.*?omni\.ja\]:.+?reported.+?length.+?-[1-9][0-9]*.+?bytes.+?long.+?Compensating\.{3}$'
  
  if ! (shopt -s nullglob; unzipped_files=(/tmp/omni/*); ((${#unzipped_files[@]}))); then
    echo
    echo "$(tput setaf 9)Unexpected warning(s) or error(s) in unzip; terminating.$(tput sgr 0)" >&2
    echo "${unzip_errors}" >&2
    rm --recursive -- /tmp/omni
    
    return 1
  fi
  
  if [[ "${unzip_errors}" ]] && ! (echo "${unzip_errors}" | xargs | grep --extended-regexp --quiet -- "${expected_errors}"); then
    echo
    echo "Note: unexpected warning(s) or error(s) in unzip:"
    echo "${unzip_errors}"
    echo
  fi
  
  return 0
}

function fix_firefox(){
  local create_backup='y'
  local restore_backup=''
  
  if [[ -f /tmp/omni.ja~ ]]; then
    read -p 'Create backup of omni.ja before applying the fix? This overwrites the old backup! [y/N] ' -r create_backup
  fi
  
  if [[ "${create_backup}" =~ ^[Yy]$ ]]; then
    echo "Copying '${firefox_dir}/browser/omni.ja' to '/tmp/omni.ja~'."
    cp --preserve -- "${firefox_dir}/browser/omni.ja" /tmp/omni.ja~
  fi
  
  echo "Fixing Firefox…"
  mkdir -- /tmp/omni || exit
  unzip_without_expected_errors || exit
  sed --in-place -- 's/this\._preventClickSelectsAll = this\.focused;/this._preventClickSelectsAll = true;/' /tmp/omni/modules/UrlbarInput.jsm
  sed --in-place -- 's/this\._preventClickSelectsAll = this\._textbox\.focused;/this._preventClickSelectsAll = true;/' /tmp/omni/chrome/browser/content/browser/search/searchbar.js
  (cd -- /tmp/omni || exit; zip -0 --no-dir-entries --quiet --recurse-paths --strip-extra omni.ja -- ./*)
  mv -- /tmp/omni/omni.ja "${firefox_dir}/browser/omni.ja" || exit
  chown --reference=/tmp/omni.ja~ -- "${firefox_dir}/browser/omni.ja"
  chmod --reference=/tmp/omni.ja~ -- "${firefox_dir}/browser/omni.ja"
  rm --recursive -- /tmp/omni
  touch -- "${firefox_dir}/browser/.purgecaches"
  echo 'Your Firefox should now be able to run with an improved user experience! Start Firefox and try it out.'
  read -p 'Press [Enter] to exit. If Firefox does not run properly, restore the backup by pressing [r], then [Enter]. ' -r restore_backup
  
  if [[ "${restore_backup}" =~ [Rr] ]]; then
    echo "Copying '/tmp/omni.ja~' to '${firefox_dir}/browser/omni.ja'."
    cp --preserve -- /tmp/omni.ja~ "${firefox_dir}/browser/omni.ja"
    touch -- "${firefox_dir}/browser/.purgecaches"
  else
    echo 'You can restore the backup later on by typing these two commands:'
    echo "$(tput setaf 14)cp -p /tmp/omni.ja~ '${firefox_dir}/browser/omni.ja'"
    echo "touch '${firefox_dir}/browser/.purgecaches'$(tput sgr 0)"
    echo "You can also copy the file '/tmp/omni.ja~' to another backup location."
  fi
}

if [[ "${FIXFX_FIREFOX_PATH}" ]]; then
  firefox_dir="${FIXFX_FIREFOX_PATH}"
else
  mapfile -t firefox_dirs < <(whereis -b firefox firefox-esr | sed --regexp-extended --expression='s/^.*?:\s*//g' | xargs | tr ' ' '\n')
  choose_firefox_path || exit

  if [[ -f "${firefox_dir}/browser/.purgecaches" ]]; then
    echo "Error: You need to start and close Firefox again to apply the changes before running this script." >&2
    
    exit 1
  fi
fi

root_required_reason="$(check_root_required)"

if [[ ! "${FIXFX_SUPPRESS_DESCRIPTION}" ]]; then
  if [[ "${root_required_reason}" && $(id --user) -ne 0 ]]; then
    echo "${description}."
  else
    read -p "${description}, then press [Enter] to continue. " -r
  fi
fi

if [[ "${root_required_reason}" ]]; then
  if [[ "${root_required_reason}" != "${reason_already_root}" ]]; then
    echo "Continue as root: write access to ${root_required_reason@Q} is required."
  fi
  
  require_root
else
  fix_firefox
fi

bash
