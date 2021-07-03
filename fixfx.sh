#!/bin/bash
# shellcheck disable=SC2155

# Script repo: https://github.com/SebastianSimon/firefox-omni-tweaks

set -o 'nounset'

readonly fallback_firefox_dir='/usr/lib/firefox' # Fallback path: put your Firefox install path here. The install path includes the `firefox` binary and a `browser` directory.

readonly description='The FixFx script tweaks Firefox. Make sure Firefox is up-to-date and closed.'
readonly reason_already_root='already_root'
readonly unpack_dir='/tmp/fixfx-omni'
readonly absolute_bash_source="$(readlink --canonicalize -- "${BASH_SOURCE[0]}")"
declare -A -r formatting=(
  [red]="$(tput -- 'setaf' '9')"
  [yellow]="$(tput -- 'setaf' '11')"
  [cyan]="$(tput -- 'setaf' '14')"
  [reset]="$(tput -- 'sgr' '0')"
)
declare -A settings=(
  # Begin presets.
  [quiet]=''
  [firefox_dir]=''
  [backup_dir]='/tmp'
  [options|preventClickSelectsAll]='on'
  [options|doubleClickSelectsAll]=''
  [options|autoSelectCopiesToClipboard]=''
  [options|autoCompleteCopiesToClipboard]=''
  [options|tabSwitchCopiesToClipboard]=''
  # End presets.
)
is_interactive=''
valid_firefox_dirs=()
backup_instructions=''
backup_target=''
backup_dir=''
firefox_dir=''

leave_terminal_window_open(){
  local executed_via_file_dialog=''
  local executed_in_terminal_window=''
  
  if [[ "$(readlink --canonicalize -- "/proc/$(ps -o 'ppid:1=' --pid "${$}")/exe")" != "$(readlink --canonicalize -- "${SHELL}")" ]]; then
    executed_via_file_dialog='true'
  fi
  
  if [[ "${COLORTERM-}" ]]; then
    executed_in_terminal_window='true'
  fi
  
  if [[ ! "${executed_via_file_dialog}" || ! "${executed_in_terminal_window}" ]] || [ "$(id --user)" -eq '0' ]; then
    return '1'
  fi
}

cleanup(){
  if [[ -d "${unpack_dir}" ]]; then
    rm --force --recursive -- "${unpack_dir}"
  fi
  
  if [[ "${backup_instructions}" ]]; then
    echo "${backup_instructions}"
  fi
}

terminate(){
  local -r status="${1}"
  
  if [ "${status}" -gt '0' ]; then
    echo " Terminating." >&2
  fi
  
  cleanup
  
  if leave_terminal_window_open; then
    exec 'bash'
  fi
  
  exit "${status}"
}

combined_short_options(){
  if [[ ! "${1}" =~ ^-[^-].+ ]]; then
    return '1'
  fi
}

is_option_key(){
  local -r option_name="${1}"
  
  case "${option_name}" in
    '-b' | '--backup' | '-f' | '--firefox' | '-o' | '--option')
      return '0'
      ;;
  esac
  
  return '1'
}

separate_flag_option_with_hyphen(){
  local -r option_name="${1}"
  
  if is_option_key "${option_name}"; then
    echo ''
  else
    echo '-'
  fi
}

assert_key_option_has_value(){
  local -r option_name="${1}"
  
  if is_option_key "${option_name}" && [ "${#}" -lt '2' ]; then
    return '1'
  fi
}

show_usage(){
  echo "Usage: ${BASH_SOURCE[0]} [OPTION...]
OPTIONs '-f', '--firefox', '-b', and '--backup' need a PATH value.
OPTIONs '-o' and '--option' need a FIX_OPTION value.
Type '${BASH_SOURCE[0]} --help' for more information."
}

show_help(){
  echo "Usage: ${BASH_SOURCE[0]} [OPTION...]
Various tweaks in the omni.ja file of your Firefox installation.

OPTIONs:
  -f PATH, --firefox PATH    Pick PATH as the Firefox install path which is to
                               be fixed.
  
  -o FIX_OPTION,             Choose which tweak to apply to omni.ja. FIX_OPTION
  --option FIX_OPTION          is 'FIX_OPTION_KEY' or 'FIX_OPTION_KEY=' to
                               turn a tweak on or off, respectively;
                               FIX_OPTION can also be 'FIX_OPTION_KEY=VALUE',
                               if a FIX_OPTION_KEY accepts a specific VALUE.
  
  -b PATH, --backup PATH     Store backup of internal Firefox file
                               'browser/omni.ja' in PATH; default: ${settings[backup_dir]@Q}.
  
  -q, --quiet                Do not log every step; do not ask for
                               confirmation; without -f, use the most recently
                               updated Firefox.
  
  -h, -?, --help, --?        Show this help and exit.

FIX_OPTION_KEYs:
  autoSelectCopiesToClipboard
                             Copy selection to clipboard always when text in
                               the URL bar or search bar is selected, e.g.
                               when pressing [Ctrl] + [L] or [F6], but not
                               when switching tabs or when auto-completing
                               URLs; ${settings[options|autoSelectCopiesToClipboard]:-off} by default.
  
  autoCompleteCopiesToClipboard
                             Requires autoSelectCopiesToClipboard. Also copies
                               selection to clipboard when auto-completing
                               URLs; ${settings[options|autoCompleteCopiesToClipboard]:-off} by default.
  
  doubleClickSelectsAll      Double-clicking the URL bar or the search bar
                               selects the entire input field; ${settings[options|doubleClickSelectsAll]:-off} by default.
  
  preventClickSelectsAll     Clicking the URL bar or the search bar no longer
                               selects the entire input field; ${settings[options|preventClickSelectsAll]:-off} by default.
  
  tabSwitchCopiesToClipboard
                             Requires autoSelectCopiesToClipboard. Also copies
                               selection to clipboard when switching tabs;
                               ${settings[options|autoCompleteCopiesToClipboard]:-off} by default.

Examples:
  # Fix a specific Firefox installation located at '/usr/lib/firefox-de_DE'.
  #   This directory must contain a 'browser/omni.ja'.
  ${BASH_SOURCE[0]} --firefox /usr/lib/firefox-de_DE
  
  # Fix default Firefox installation and store backups of 'browser/omni.ja'
  #   in the specified directory. The file names will be incremental, e.g.
  #   'omni-0.ja~', 'omni-1.ja~', etc.
  ${BASH_SOURCE[0]} -b /home/user/backups/my_backup_directory
  
  # In this case, the file name 'my_omni_backup.ja~' is used for the backup.
  #   The file is overwritten, if it exists.
  ${BASH_SOURCE[0]} -b /home/user/backups/my_omni_backup.ja~
  
  # Like the double-click-selects-all behavior on the URL bar? Use this:
  ${BASH_SOURCE[0]} -o preventClickSelectsAll -o doubleClickSelectsAll

Exit codes:
    0  Success
    1  File system error, e.g. missing permissions, file not found, etc.
    2  Incorrect script usage, e.g. incorrect options or conditions, etc.
  130  Interrupt or kill signal received

Script source, full documentation, bug reports at:
  <https://github.com/SebastianSimon/firefox-omni-tweaks>"
}

set_options(){
  while [ "${#}" -gt '0' ]; do
    if combined_short_options "${1}"; then
      set -- "${1:0:2}" "$(separate_flag_option_with_hyphen "${1:0:2}")${1:2}" "${@:2}"
    fi
    
    assert_key_option_has_value "${@}" || {
      echo "${formatting[red]}Error: No value provided for option ${1@Q}.${formatting[reset]}" >&2
      echo
      show_usage
      terminate '2'
    }
    
    case "${1}" in
      '--')
        break
        ;;
      '-b' | '--backup')
        settings[backup_dir]="${2}"
        shift
        ;;
      '-f' | '--firefox')
        settings[firefox_dir]="${2}"
        shift
        ;;
      '-o' | '--option')
        if [[ "${2}" =~ \= ]]; then
          settings["options|${2%%=*}"]="${2#*=}"
        else
          settings["options|${2}"]='on'
        fi
        
        shift
        ;;
      '-h' | '-?' | '--help' | '--?')
        show_help
        
        exit
        ;;
      '-q' | '--quiet')
        settings[quiet]='true'
        ;;
    esac
    
    shift
  done
}

check_root_required(){
  if [ "$(id --user)" -eq '0' ]; then
    echo "${reason_already_root}"
    
    return
  fi
  
  local path
  
  for path in "$(dirname -- "${unpack_dir}")" "${backup_target}" "${firefox_dir}/browser" "${firefox_dir}/browser/omni.ja"; do
    if [[ ! -w "${path}" ]]; then
      echo "${path}"
      
      return
    fi
  done
}

require_root(){
  if [ "$(id --user)" -ne '0' ]; then
    sudo 'env' FIXFX_SWITCHED_TO_ROOT='true' "${absolute_bash_source}" "${@}"
  fi
}

find_backup_target(){
  local -r containing_dir="$(dirname -- "${settings[backup_dir]}")"
  
  if [[ ! -d "${containing_dir}" ]]; then
    echo "${formatting[red]}Error: ${settings[backup_dir]@Q} is not an existing directory or a file within an existing directory.${formatting[reset]}" >&2
    
    return '2'
  fi
  
  if [[ ! -e "${settings[backup_dir]}" ]]; then
    echo "${containing_dir}"
  elif [[ -d "${settings[backup_dir]}" || -f "${settings[backup_dir]}" ]]; then
    echo "${settings[backup_dir]}"
  else
    echo "${formatting[red]}Error: ${settings[backup_dir]@Q} is not a regular file.${formatting[reset]}" >&2
    
    return '2'
  fi
}

initialize_backup_target(){
  find_backup_target 1>'/dev/null' || return "${?}"
  
  if [[ -d "${settings[backup_dir]}" ]]; then
    local -r start="${settings[backup_dir]}/omni-"
    local -r end='.ja~'
    local incremental_number='0'
    
    while ! (
      set -o noclobber
      echo -n '' >"${start}${incremental_number}${end}"
    ) 2>'/dev/null'; do
      ((incremental_number++))
    done
    
    echo "${start}${incremental_number}${end}"
  else
    touch -- "${settings[backup_dir]}"
    echo "${settings[backup_dir]}"
  fi
}

choose_firefox_path(){
  echo 'Multiple Firefox install paths found. Type a number to choose one path:'
  set -o 'posix'
  
  select firefox_dir in "${valid_firefox_dirs[@]}"; do
    if {
      [ 1 -le "${REPLY}" ] && [ "${REPLY}" -le "${#valid_firefox_dirs[@]}" ]
    } 2>'/dev/null'; then
      echo "Chose option ${REPLY}: ${firefox_dir@Q}."
      
      break
    else
      echo "Number ${REPLY@Q} is not a valid choice."
    fi
  done
  
  set +o 'posix'
}

find_firefox_path(){
  if [[ "${settings[firefox_dir]}" ]]; then
    if [[ -f "${settings[firefox_dir]}/browser/omni.ja" ]]; then
      firefox_dir="${settings[firefox_dir]}"
      
      return
    fi
    
    echo "${formatting[red]}Error: ${settings[firefox_dir]@Q} is not a valid Firefox install path:
  file '${settings[firefox_dir]}/browser/omni.ja' not found.${formatting[reset]}" >&2
    
    return '2'
  fi
  
  local add_fallback_path='true'
  local current_firefox_dir=''
  mapfile -t available_firefox_dirs < <(printf "%s" "$(whereis -b 'firefox' 'firefox-esr' | sed --regexp-extended --expression='s/^.*?:\s*//g' | xargs | tr ' ' '\n')")
  
  for current_firefox_dir in "${available_firefox_dirs[@]}"; do
    if [[ -f "${current_firefox_dir}/browser/omni.ja" ]]; then
      valid_firefox_dirs+=("${current_firefox_dir}")
    fi
    
    if [[ "${current_firefox_dir}" -ef "${fallback_firefox_dir}" ]]; then
      add_fallback_path=''
    fi
  done
  
  if [[ "${add_fallback_path}" ]]; then
    if [[ -f "${fallback_firefox_dir}/browser/omni.ja" ]]; then
      valid_firefox_dirs+=("${fallback_firefox_dir}")
    fi
    
    available_firefox_dirs+=("${fallback_firefox_dir}")
  fi
  
  if [ "${#valid_firefox_dirs[@]}" -eq '0' ]; then
    echo "${formatting[red]}Error: Firefox install path not found in the path(s) ${available_firefox_dirs[*]@Q}.${formatting[reset]}" >&2
    
    return '1'
  fi
  
  if [ "${#valid_firefox_dirs[@]}" -eq '1' ]; then
    firefox_dir="${valid_firefox_dirs[0]}"
    
    return
  fi
  
  current_firefox_dir=''
  
  local most_recently_updated
  
  if [[ "${settings[quiet]}" || ! "${is_interactive}" ]]; then
    for most_recently_updated in "${valid_firefox_dirs[@]}"; do
      if [[ "${most_recently_updated}/browser/omni.ja" -nt "${current_firefox_dir}/browser/omni.ja" ]]; then
        current_firefox_dir="${most_recently_updated}"
      fi
    done
  fi
  
  firefox_dir="${current_firefox_dir}"
}

greet_and_apply_options(){
  local firefox_path_chosen=''
  local needs_confirm_description_read=''
  local enabled_fix_options=()
  local fix_option
  
  for fix_option in "${!settings[@]}"; do
    if [[ "${fix_option}" =~ ^options\| && "${settings[${fix_option}]}" ]]; then
      enabled_fix_options+=("${fix_option#options|}$([[ "${settings[${fix_option}]}" != 'on' ]] && echo "="${settings[${fix_option}]})")
    fi
  done
  
  if [[ -t 1 ]]; then
    readonly is_interactive='true'
  fi
  
  if [[ "${settings[quiet]}" ]]; then
    exec 1>'/dev/null'
  fi
  
  if [[ ! "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    echo "${description}"
    
    if (("${#enabled_fix_options[@]}" == 0)); then
      echo "No tweaks enabled; repack omni.ja without edits"
    else
      echo "Enabled tweak$( (("${#enabled_fix_options[@]}" > 1)) && echo 's'): ${enabled_fix_options[*]@Q}"
    fi
  fi
  
  find_firefox_path || terminate "${?}"
  readonly valid_firefox_dirs
  
  if [[ ! "${firefox_dir}" ]]; then
    choose_firefox_path
    firefox_path_chosen='true'
  fi
  
  if [[ ! "${firefox_dir}" ]]; then
    echo "${formatting[red]}Error: Failed to determine Firefox path.${formatting[reset]}" >&2
    terminate '1'
  fi
  
  readonly firefox_dir
  
  if [[ ! "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    if [[ ! "${firefox_path_chosen}" ]]; then
      echo "Firefox location: ${firefox_dir@Q}"
    fi
    
    backup_target="$(find_backup_target)" || terminate "${?}"
    readonly backup_target
  fi
  
  root_required_reason="$(check_root_required)"
  
  if [[ "${root_required_reason}" && "${root_required_reason}" != "${reason_already_root}" ]]; then
    echo "Continue as root: write access to ${root_required_reason@Q} is required."
    require_root "${@}" || terminate "${?}"
    terminate '0'
  elif [[ ! "${settings[quiet]}" && ! "${FIXFX_SWITCHED_TO_ROOT-}" && ! "${firefox_path_chosen}" && "${is_interactive}" ]]; then
    needs_confirm_description_read='true'
  fi
  
  backup_dir="$(initialize_backup_target)" || terminate "${?}"
  readonly backup_dir
  echo "Backup location: ${backup_dir@Q}"
  
  if [[ "${needs_confirm_description_read}" ]]; then
    read -p "Press [Enter] to continue. " -r
  fi
}

unzip_without_expected_errors(){
  local -r unzip_errors="$(unzip -d "${unpack_dir}" -o -qq -- "${firefox_dir}/browser/omni.ja" 2>&1)"
  local -r expected_errors='^warning.+?\[.*?omni\.ja\]:.+?[1-9][0-9]*.+?extra.+?bytes.+?attempting.+?anyway.+?error.+?\[.*?omni\.ja\]:.+?reported.+?length.+?-[1-9][0-9]*.+?bytes.+?long.+?Compensating\.{3}(.+[0-9]+.+archive.+error.+)?$'
  
  if ! (
    shopt -s 'nullglob'
    unzipped_files=("${unpack_dir}/"*)
    ((${#unzipped_files[@]}))
  ); then
    echo
    echo "${formatting[red]}Error: Unexpected warning(s) or error(s) in unzip.${formatting[reset]}" >&2
    echo "${unzip_errors}" >&2
    
    return '1'
  fi
  
  if [[ "${unzip_errors}" ]] && ! xargs <<< "${unzip_errors}" | grep --extended-regexp --quiet -- "${expected_errors}"; then
    echo
    echo "${formatting[yellow]}Warning: unexpected warning(s) or error(s) in unzip:"
    echo "${unzip_errors}${formatting[reset]}"
    echo
  fi
}

edit_file(){
  local -r purpose="${1}"
  local -r input_file="${2}"
  
  shift 2
  
  local -r fixed_flag_file="$(dirname -- "${unpack_dir}/${input_file}")/.$(basename -- "${unpack_dir}/${input_file}").${purpose}"
  
  if (("${#@}" == 0)); then
    touch -- "${fixed_flag_file}"
    
    return
  fi
  
  local regex
  local regexes=()
  local regex_index='1'
  local match_index='1'
  
  for regex in "${@}"; do
    regexes+=("--expression=${regex} w ${fixed_flag_file}.${regex_index}")
    ((regex_index++))
  done
  
  if [[ -f "${fixed_flag_file}" ]]; then
    return
  fi
  
  sed --in-place --regexp-extended "${regexes[@]}" "${unpack_dir}/${input_file}" \
    && touch -- "${fixed_flag_file}"

  while (("${match_index}" < "${regex_index}")); do
    if [[ ! -s "${fixed_flag_file}.${match_index}" ]]; then
      echo "${formatting[yellow]}Warning: Pattern '${*:match_index:1}' could not be matched in file ${input_file@Q}.${formatting[reset]}" >&2
      
      break
    fi
    
    rm -- "${fixed_flag_file}.${match_index}"
    ((match_index++))
  done
}

edit_and_lock_based_on_options(){
  if [[ "${settings[options|preventClickSelectsAll]-}" ]]; then
    edit_file 'preventClickSelectsAll' 'modules/UrlbarInput.jsm' 's/(this\._preventClickSelectsAll = )this\.focused;/\1true;/'
    edit_file 'preventClickSelectsAll' 'chrome/browser/content/browser/search/searchbar.js' 's/(this\._preventClickSelectsAll = )this\._textbox\.focused;/\1true;/'
  fi

  if [[ "${settings[options|doubleClickSelectsAll]-}" ]]; then
    edit_file 'doubleClickSelectsAll' 'modules/UrlbarInput.jsm' 's/(if \(event\.target\.id == SEARCH_BUTTON_ID\) \{)/if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        } else \1/'
    edit_file 'doubleClickSelectsAll' 'chrome/browser/content/browser/search/searchbar.js' '/this\.addEventListener\("mousedown", event => \{/,/\}\);/ s/(\}\);)/        \n        if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        }\n      \1/'
  fi
  
  if [[ "${settings[options|autoSelectCopiesToClipboard]-}" ]]; then
    edit_file 'autoSelectCopiesToClipboard' 'modules/UrlbarInput.jsm' 's/(_on_select\(event\) \{)/\1\n    this.window.fixfx_isOpeningLocation = false;\n    /' \
      's/(this\._suppressPrimaryAdjustment = )true;/\1false;/' \
      's/(this\.inputField\.select\(\);)/\1\n    \n    if(this.window.fixfx_isOpeningLocation){\n      this._on_select({\n        detail: {\n          fixfx_openingLocationCall: true\n        }\n      });\n    }\n    /'
    edit_file 'autoSelectCopiesToClipboard' 'chrome/browser/content/browser/browser.js' '/function openLocation/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isOpeningLocation = true;\n    \1/' \
      's/^(\s*searchBar\.select\(\);)$/      window.fixfx_isOpeningSearch = true;\n\1/'
    edit_file 'autoSelectCopiesToClipboard' 'chrome/browser/content/browser/tabbrowser.js' '/_adjustFocusAfterTabSwitch\(newTab\) \{/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isSwitchingTab = true;\n          \1/'
    edit_file 'autoSelectCopiesToClipboard' 'chrome/browser/content/browser/search/searchbar.js' 's/^\{$/{\n  XPCOMUtils.defineLazyServiceGetter(this, "ClipboardHelper", "@mozilla.org\/widget\/clipboardhelper;1", "nsIClipboardHelper");\n  /' \
      's/(this\._textbox\.select\(\);)/\1\n      \n      if(window.fixfx_isOpeningSearch){\n        this.textbox.dispatchEvent(new Event("select"));\n      }/' \
      's/(_setupTextboxEventListeners\(\) \{)/\1\n      this.textbox.addEventListener("select", () => {\n        window.fixfx_isOpeningSearch = false;\n        \n        if(this.value \&\& Services.clipboard.supportsSelectionClipboard()){\n          ClipboardHelper.copyStringToClipboard(this.value, Services.clipboard.kSelectionClipboard);\n        }\n      });\n      /'
    
    if [[ "${settings[options|tabSwitchCopiesToClipboard]-}" ]]; then
      edit_file 'tabSwitchCopiesToClipboard' 'modules/UrlbarInput.jsm' 's/^\s*!this\.window\.windowUtils\.isHandlingUserInput \|\|$//'
    else
      edit_file 'tabSwitchCopiesToClipboard' 'modules/UrlbarInput.jsm' 's/(_on_select\(event\) \{)/\1\n    if(event?.detail?.fixfx_openingLocationCall){\n      this.window.fixfx_isSwitchingTab = false;\n    }\n    \n    const fixfx_isSwitchingTab = this.window.fixfx_isSwitchingTab;\n    \n    if(this.window.fixfx_isSwitchingTab){\n      this.window.setTimeout(() => this.window.setTimeout(() => this.window.fixfx_isSwitchingTab = false));\n    }\n    /' \
        's/!this\.window\.windowUtils\.isHandlingUserInput \|\|/fixfx_isSwitchingTab ||/'
    fi
    
    if [[ ! "${settings[options|autoCompleteCopiesToClipboard]-}" ]]; then
      edit_file 'autoCompleteCopiesToClipboard' 'modules/UrlbarInput.jsm' '/_on_select\(event\) \{/,/ClipboardHelper/ s/(if \(!val)\)/\1 || !this.window.windowUtils.isHandlingUserInput \&\& val !== this.inputField.value \&\& this.inputField.value.endsWith(val))/'
    fi
  fi
}

prepare_backup_instructions(){
  echo 'You can restore the backup later on by typing these two commands:'
  echo "${formatting[cyan]}cp -p ${backup_dir@Q} '${firefox_dir}/browser/omni.ja'"
  echo "touch '${firefox_dir}/browser/.purgecaches'${formatting[reset]}"
  echo "You can also copy the file ${backup_dir@Q} to another backup location."
}

clear_firefox_caches(){
  local -r cache_dir="$(getent passwd "${SUDO_USER:-${USER}}" | cut --delimiter=':' --fields='6')/.cache/mozilla/firefox"
  local startup_cache
  
  if [[ -d "${cache_dir}" ]]; then
    shopt -s 'nullglob'
    
    for startup_cache in "${cache_dir}/"*'/startupCache'; do
      rm --recursive --force -- "${startup_cache}" 2>'/dev/null' \
        && echo "Clearing startup cache in '$(dirname -- "${startup_cache}")'."
    done
    
    shopt -u 'nullglob'
  fi
  
  touch -- "${firefox_dir}/browser/.purgecaches" \
    && chown --reference="${firefox_dir}/browser" -- "${firefox_dir}/browser/.purgecaches"
}

fix_firefox(){
  cp --preserve -- "${firefox_dir}/browser/omni.ja" "${backup_dir}" \
    && echo "Copying '${firefox_dir}/browser/omni.ja' to ${backup_dir@Q}."
  echo "Fixing Firefox…"
  mkdir -- "${unpack_dir}" || terminate '1'
  unzip_without_expected_errors || terminate "${?}"
  edit_and_lock_based_on_options
  (
    cd -- "${unpack_dir}" || terminate '1'
    zip -0 --no-dir-entries --quiet --recurse-paths --strip-extra omni.ja -- './'*
  )
  mv -- "${unpack_dir}/omni.ja" "${firefox_dir}/browser/omni.ja" || terminate '1'
  backup_instructions="$(prepare_backup_instructions)"
  chown --reference="${firefox_dir}/browser" -- "${firefox_dir}/browser/omni.ja"
  clear_firefox_caches
  echo 'The tweaks should be applied now! Start Firefox and try it out.'
}

offer_backup_restore(){
  local restore_backup_reply=''
  
  if [[ ! "${settings[quiet]}" && "${is_interactive}" ]]; then
    read -p 'Press [Enter] to exit. Press [r], then [Enter] to restore the backup. ' -r restore_backup_reply
  fi
  
  if [[ "${restore_backup_reply}" =~ [Rr] ]]; then
    if [[ -f "${backup_dir}" ]]; then
      cp --preserve -- "${backup_dir}" "${firefox_dir}/browser/omni.ja" \
        && echo "Copying ${backup_dir@Q} to '${firefox_dir}/browser/omni.ja'."
      clear_firefox_caches
    else
      echo "The original backup at ${backup_dir@Q} no longer exists."
    fi
  else
    echo "${backup_instructions}"
  fi
  
  readonly backup_instructions=''
}

trap -- 'terminate 130' 'INT' 'TERM'
set_options "${@}"
greet_and_apply_options "${@}"
fix_firefox
offer_backup_restore
terminate '0'
