#!/bin/bash
# shellcheck disable=SC2155

# Script repo: https://github.com/SebastianSimon/firefox-omni-tweaks

set -o 'nounset'

readonly description='The FixFx script tweaks Firefox. Make sure Firefox is up-to-date and closed.'
readonly reason_already_root='already_root'
readonly absolute_bash_source="$(readlink --canonicalize -- "${BASH_SOURCE[0]}")"
readonly is_interactive="$([[ -t 1 ]] && echo 'true')"
declare -A -r unpack_dirs=(
  [omni]="/tmp/fixfx-omni"
  [browser_omni]="/tmp/fixfx-browser_omni"
)
declare -A -r unpack_targets=(
  [omni]='omni.ja'
  [browser_omni]='browser/omni.ja'
)
declare -A -r formatting=(
  [red]="$(tput -- 'setaf' '9')"
  [yellow]="$(tput -- 'setaf' '11')"
  [cyan]="$(tput -- 'setaf' '14')"
  [reset]="$(tput -- 'sgr' '0')"
)
declare -A settings=(
  # Begin presets.
  [addAllFound]=''
  [backup_dir]='/tmp'
  # Entries like [firefox_dirs|0]='/usr/lib/firefox' get added here dynamically or via Web interface.
  [fixOnlyYoungest]=''
  [options|preventClickSelectsAll]='on'
  [options|doubleClickSelectsAll]=''
  [options|autoSelectCopiesToClipboard]=''
  [options|autoCompleteCopiesToClipboard]=''
  [options|tabSwitchCopiesToClipboard]=''
  [options|secondsSeekedByKeyboard]=''
  [quiet]=''
  # End presets.
)
declare -A backup_targets=(
  [omni]=''
  [browser_omni]=''
)
needs_confirm_description_read="$([[ "${is_interactive}" ]] || echo 'true')"
backup_instructions=''
declare -A collected_firefox_dirs
filtered_firefox_dirs=()
explicit_script_params=()

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
  local unpack_dir
  
  for unpack_dir in "${unpack_dirs[@]}"; do
    if [[ -d "${unpack_dir}" ]]; then
      rm --force --recursive -- "${unpack_dir}"
    fi
  done
  
  if [[ "${backup_instructions}" ]]; then
    echo "${backup_instructions}"
  fi
}

terminate(){
  local -r status="${1}"
  
  if (("${status}" > 0)); then
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

fix_option_default_value(){
  local -r fix_key="${1}"
  
  case "${fix_key}" in
    'autoSelectCopiesToClipboard' | 'autoCompleteCopiesToClipboard' | 'doubleClickSelectsAll' | 'preventClickSelectsAll' | 'tabSwitchCopiesToClipboard')
      echo 'on'
      ;;
    *)
      echo ''
  esac
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
  
  if is_option_key "${option_name}" && (("${#}" < 2)); then
    return '1'
  fi
}

show_usage(){
  echo "Usage: ${BASH_SOURCE[0]} [OPTION...]
OPTIONs '-f', '--firefox', '-b', and '--backup' need a DIR value.
OPTIONs '-o' and '--option' need a FIX_OPTION value.
Type '${BASH_SOURCE[0]} --help' for more information."
}

show_help(){
  echo "Usage: ${BASH_SOURCE[0]} [OPTION...]
Various tweaks in the omni.ja files of your Firefox installation.

By default, the script tries to find all Firefox and Firefox ESR paths to the
selection, then, if more than one path is found, asks interactively which ones
to fix. Executing the script non-interactively fixes all paths by default.
Providing the -a or -f or -q or -y option disables the interactive filtering,
and instead fixes all paths, explicitly provided paths, or only the most
recently modified path.

OPTIONs:
  -f DIR, --firefox DIR      Add DIR as a Firefox (ESR) install path to the
                               selection that needs fixing.
  
  -a, --add-all-found        Automatically find all Firefox (ESR) install paths
                               and add them to the selection that needs fixing.
  
  -y, --fix-only-youngest    Pick only the youngest Firefox (ESR) install path
                               from the selection, i.e. latest modification /
                               install date, to be fixed.
  
  -o FIX_OPTION,             Choose which tweak to apply to omni.ja. FIX_OPTION
  --option FIX_OPTION          is 'FIX_OPTION_KEY' or 'FIX_OPTION_KEY=' to
                               turn a tweak on or off, respectively;
                               FIX_OPTION can also be 'FIX_OPTION_KEY=VALUE',
                               if a FIX_OPTION_KEY requires a specific VALUE.
  
  -b DIR, --backup DIR       Store backup of internal Firefox files 'omni.ja'
                               and 'browser/omni.ja' in DIR; directory is
                               created if it doesn’t exist, but parent
                               directory must exist; default: ${settings[backup_dir]@Q}.
  
  -q, --quiet                Do not log every step; do not ask for
                               confirmation.
  
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
  
  secondsSeekedByKeyboard
                             Seeking by keyboard controls in the default video
                               player or in the PiP mode (using [←] or [→])
                               will seek by VALUE seconds; default: ${settings[options|autoCompleteCopiesToClipboard]:-no change}.
  
  tabSwitchCopiesToClipboard
                             Requires autoSelectCopiesToClipboard. Also copies
                               selection to clipboard when switching tabs;
                               ${settings[options|autoCompleteCopiesToClipboard]:-off} by default.

Examples:
  # Fix all Firefox installations that are automatically found, then
  #   interactively ask which ones to fix, if more than one is found.
  ${BASH_SOURCE[0]}
  
  # Fix all Firefox installations that are automatically found.
  ${BASH_SOURCE[0]} -a
  ${BASH_SOURCE[0]} --quiet
  ${BASH_SOURCE[0]} --add-all-found -q
  
  # Fix a specific Firefox installation located at '/usr/lib/firefox-de_DE'
  #   as well as one located at '/usr/lib/firefox-de_DE'. These directories
  #   must contain an 'omni.ja' and a 'browser/omni.ja' each.
  ${BASH_SOURCE[0]} --firefox /usr/lib/firefox-de_DE -f /usr/lib/firefox-pt_BR
  ${BASH_SOURCE[0]} -f /usr/lib/firefox-de_DE -f /usr/lib/firefox-pt_BR -q
  
  # Fix a specific Firefox installation located at '/usr/lib/firefox-de_DE'
  #   and all others that are automatically found.
  ${BASH_SOURCE[0]} -a -f /usr/lib/firefox-de_DE
  ${BASH_SOURCE[0]} -a -f /usr/lib/firefox-de_DE -q
  
  # Of all Firefox installations and '/usr/lib/firefox-de_DE', fix only the
  #   youngest and store backups of 'omni.ja' and 'browser/omni.ja' in
  #   '/home/user/fx_backups'. The file names will be incremental, e.g.
  #   'omni-0.ja~', 'omni-1.ja~', etc.
  ${BASH_SOURCE[0]} -a -f /usr/lib/firefox-de_DE -q -y -b /home/user/fx_backups
  
  # Like the double-click-selects-all behavior on the URL bar? Use this:
  ${BASH_SOURCE[0]}$([[ ! "${settings[options|preventClickSelectsAll]}" ]] && echo ' -o preventClickSelectsAll') -o doubleClickSelectsAll

Exit codes:
    0  Success
    1  File system error, e.g. missing permissions, file not found, etc.
    2  Incorrect script usage, e.g. incorrect options or conditions, etc.
  130  Interrupt or kill signal received

Script source, full documentation, bug reports at:
  <https://github.com/SebastianSimon/firefox-omni-tweaks>"
}

set_options(){
  local firefox_dirs_count='0'
  
  while (("${#}" > 0)); do
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
        settings["firefox_dirs|${firefox_dirs_count}"]="${2}"
        ((firefox_dirs_count++))
        
        shift
        ;;
      '-a' | '--add-all-found')
        settings[addAllFound]='true'
        ;;
      '-y' | '--fix-only-youngest')
        settings[fixOnlyYoungest]='true'
        ;;
      '-o' | '--option')
        if [[ "${2}" =~ \= ]]; then
          settings["options|${2%%=*}"]="${2#*=}"
        else
          settings["options|${2}"]="$(fix_option_default_value "${2}")"
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

get_options(){ # TODO Repetitive code.
  local filtered_firefox_dir
  
  explicit_script_params+=('-b' "${settings[backup_dir]}")
  
  for filtered_firefox_dir in "${filtered_firefox_dirs[@]}"; do
    explicit_script_params+=('-f' "${filtered_firefox_dir}")
  done
  
  explicit_script_params+=(
    '-o' "preventClickSelectsAll=${settings[options|preventClickSelectsAll]}"
    '-o' "doubleClickSelectsAll=${settings[options|doubleClickSelectsAll]}"
    '-o' "autoSelectCopiesToClipboard=${settings[options|autoSelectCopiesToClipboard]}"
    '-o' "autoCompleteCopiesToClipboard=${settings[options|autoCompleteCopiesToClipboard]}"
    '-o' "tabSwitchCopiesToClipboard=${settings[options|tabSwitchCopiesToClipboard]}"
    '-o' "secondsSeekedByKeyboard=${settings[options|secondsSeekedByKeyboard]}"
  )
  
  if [[ "${settings[quiet]}" ]];
    explicit_script_params+=('-q')
  fi
}

check_root_required(){ # TODO Repetitive code.
  declare -A checked_directories
  local firefox_dir
  local package_key
  local path
  
  if [ "$(id --user)" -eq '0' ]; then
    echo "${reason_already_root}"
    
    return
  fi
  
  for package_key in 'omni' 'browser_omni'; do
    for path in "$(dirname -- unpack_dirs[${package_key}])"; do # TODO: readlink --canonicalize?
      if [[ "${checked_directories[${path}]-}" ]]; then
        continue
      fi
      
      checked_directories["${path}"]='checked'
      
      if [[ ! -w "${path}" ]]; then
        echo "${path}"
        
        return
      fi
    done
  
    for firefox_dir in "${filtered_firefox_dirs[@]}"; do
      for path in "$(dirname -- "${firefox_dir}/${unpack_targets[${package_key}]}")" "${firefox_dir}/${unpack_targets[${package_key}]}"; do # TODO: readlink --canonicalize?
        if [[ "${checked_directories[${path}]-}" ]]; then
          continue
        fi
        
        checked_directories["${path}"]='checked'
        
        if [[ ! -w "${path}" ]]; then
          echo "${path}"
          
          return
        fi
      done
    done
  done
  
  for path in "${@}"; do
    if [[ "${checked_directories[${path}]-}" ]]; then
      continue
    fi
    
    checked_directories["${path}"]='checked'
    
    if [[ ! -w "${path}" ]]; then
      echo "${path}"
      
      return
    fi
  done
}

require_root(){
  if [ "$(id --user)" -ne '0' ]; then
    get_options
    sudo 'env' FIXFX_SWITCHED_TO_ROOT='true' "${absolute_bash_source}" "${explicit_script_params[@]}"
  fi
}

find_backup_dir(){
  if [[ ! -e "${settings[backup_dir]}" && -d "$(dirname -- "${settings[backup_dir]}")" || -d "${settings[backup_dir]}" ]]; then
    echo "$(readlink --canonicalize -- "${settings[backup_dir]}")"
  else
    echo "${formatting[red]}Error: ${settings[backup_dir]@Q} has no parent directory or is not a directory itself.${formatting[reset]}" >&2
    
    return '2'
  fi
}

initialize_backup_target(){
  local prefix="${1}"
  local -r start="${settings[backup_dir]}/${prefix}-"
  local -r end='.ja~'
  local incremental_number='0'
  
  if [[ ! -e "${settings[backup_dir]}" && -d "$(dirname -- "${settings[backup_dir]}")" ]]; then
    mkdir "${settings[backup_dir]}"
  fi
  
  find_backup_dir 1>'/dev/null' || return "${?}"
  
  while ! (
    set -o noclobber
    echo -n '' >"${start}${incremental_number}${end}"
  ) 2>'/dev/null'; do
    ((incremental_number++))
  done
  
  echo "$(readlink --canonicalize -- "${start}${incremental_number}${end}")"
}

collect_firefox_dirs(){
  local firefox_dirs_count='0'
  local found_firefox_dir
  local found_firefox_dirs
  
  while [[ -v settings["firefox_dirs|${firefox_dirs_count}"] ]]; do
    if [[ -f "${settings["firefox_dirs|${firefox_dirs_count}"]}/omni.ja" && -f "${settings["firefox_dirs|${firefox_dirs_count}"]}/browser/omni.ja" ]];
      collected_firefox_dirs["${settings["firefox_dirs|${firefox_dirs_count}"]}"]='1'
    else
      echo "${formatting[yellow]}Warning: ${settings["firefox_dirs|${firefox_dirs_count}"]@Q} is not a Firefox installation path.${formatting[reset]}" >&2
    fi
    
    ((firefox_dirs_count++))
  done

  if [[ ! "${is_interactive}" || "${settings[addAllFound]}" || ! -v settings['firefox_dirs|0'] ]]; then
    mapfile -t found_firefox_dirs < <(printf "%s" "$(whereis -b 'firefox' 'firefox-esr' | sed --regexp-extended --expression='s/^.*?:\s*//g' | xargs | tr ' ' '\n')")
    
    for found_firefox_dir in "${found_firefox_dirs[@]}"; do
      if [[ -f "${found_firefox_dir}/omni.ja" && -f "${found_firefox_dir}/browser/omni.ja" ]];
        collected_firefox_dirs["${found_firefox_dir}"]='1'
      fi
    done
  fi
}

filter_include_all(){
  local collected_firefox_dir
  
  for collected_firefox_dir in "${!collected_firefox_dirs[@]}"; do
    filtered_firefox_dirs+=("${collected_firefox_dir}")
  done
}

filter_firefox_dirs(){
  local collected_firefox_dir
  local most_recently_updated
  local firefox_reply
  local current_firefox_dir=''
  local chosen_firefox_index
  local firefox_choices=()
  
  if [[ "${settings[fixOnlyYoungest]}" ]]; then
    for most_recently_updated in "${!collected_firefox_dirs[@]}"; do
      if [[ "${most_recently_updated}/browser/omni.ja" -nt "${current_firefox_dir}/browser/omni.ja" ]]; then
        current_firefox_dir="${most_recently_updated}"
      fi
    done
    
  
    if (("${#collected_firefox_dirs[@]}" > 0)); then
      filtered_firefox_dirs+=("${current_firefox_dir}")
    fi
  elif [[ "${is_interactive}" && ! "${settings[addAllFound]}" && ! -v settings['firefox_dirs|0'] && ! "${settings[quiet]}" ]] && (("${#collected_firefox_dirs[@]}" > 1)); then
    echo 'Multiple Firefox install paths found. Type numbers to choose paths; leave empty to choose all. Non-numbers are ignored.'
    
    # Multiple choice.
    for collected_firefox_dir in "${!collected_firefox_dirs[@]}"; do
      firefox_choices+=("${collected_firefox_dir}")
      echo "$(printf %2s "${#firefox_choices}"): ${collected_firefox_dir}"
    done
    
    needs_confirm_description_read=''
    read -p 'Choose: ' -r firefox_reply
    mapfile -t chosen_firefox_indexes < <(grep -E '[0-9]+' -o <<< "${firefox_reply}")
    
    if (("${#chosen_firefox_dirs[@]}" == 0)); then
      filter_include_all
    elif
      for chosen_firefox_index in "${chosen_firefox_indexes[@]}"; do
        ((chosen_firefox_index--))
        filtered_firefox_dirs+=("${firefox_choices["${chosen_firefox_index}"]}")
      done
    fi
  else
    filter_include_all
  fi
}

unzip_without_expected_errors(){
  local -r firefox_dir="${1}"
  local -r package_key="${2}"
  local -r unzip_errors="$(unzip -d "${unpack_dirs[${package_key}]}" -o -qq -- "${firefox_dir}/${unpack_targets[${package_key}]}" 2>&1)"
  local -r expected_errors='^warning.+?\[.*?omni\.ja\]:.+?[1-9][0-9]*.+?extra.+?bytes.+?attempting.+?anyway.+?error.+?\[.*?omni\.ja\]:.+?reported.+?length.+?-[1-9][0-9]*.+?bytes.+?long.+?Compensating\.{3}(.+[0-9]+.+archive.+error.+)?$'
  
  if ! (
    shopt -s 'nullglob'
    unzipped_files=("${unpack_dirs[${package_key}]}/"*)
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
  local -r package_key="${2}"
  local -r input_file="${3}"
  local -r fixed_file="${unpack_dirs[${package_key}]}/${input_file}"
  local -r fixed_flag_file="$(dirname -- "${fixed_file}")/.$(basename -- "${fixed_file}").${purpose}"
  local regex
  local regexes=()
  local regex_index='1'
  local match_index='1'
  
  shift 3
  
  if (("${#@}" == 0)); then
    touch -- "${fixed_flag_file}"
    
    return
  fi
  
  for regex in "${@}"; do
    regexes+=("--expression=${regex} w ${fixed_flag_file}.${regex_index}")
    ((regex_index++))
  done
  
  if [[ -f "${fixed_flag_file}" ]]; then
    return
  fi
  
  sed --in-place --regexp-extended "${regexes[@]}" "${fixed_file}" \
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

edit_and_lock_based_on_options(){ # TODO: New filenames!
  if [[ "${settings[options|preventClickSelectsAll]-}" ]]; then
    edit_file 'preventClickSelectsAll' 'browser_omni' 'modules/UrlbarInput.jsm' 's/(this\._preventClickSelectsAll = )this\.focused;/\1true;/'
    edit_file 'preventClickSelectsAll' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' 's/(this\._preventClickSelectsAll = )this\._textbox\.focused;/\1true;/'
  fi

  if [[ "${settings[options|doubleClickSelectsAll]-}" ]]; then
    edit_file 'doubleClickSelectsAll' 'browser_omni' 'modules/UrlbarInput.jsm' 's/(if \(event\.target\.id == SEARCH_BUTTON_ID\) \{)/if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        } else \1/'
    edit_file 'doubleClickSelectsAll' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' '/this\.addEventListener\("mousedown", event => \{/,/\}\);/ s/(\}\);)/        \n        if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        }\n      \1/'
  fi
  
  if [[ "${settings[options|autoSelectCopiesToClipboard]-}" ]]; then
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'modules/UrlbarInput.jsm' 's/(_on_select\(event\) \{)/\1\n    this.window.fixfx_isOpeningLocation = false;\n    /' \
      's/(this\._suppressPrimaryAdjustment = )true;/\1false;/' \
      's/(this\.inputField\.select\(\);)/\1\n    \n    if(this.window.fixfx_isOpeningLocation){\n      this._on_select({\n        detail: {\n          fixfx_openingLocationCall: true\n        }\n      });\n    }\n    /'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/browser.js' '/function openLocation/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isOpeningLocation = true;\n    \1/' \
      's/^(\s*searchBar\.select\(\);)$/      window.fixfx_isOpeningSearch = true;\n\1/'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/tabbrowser.js' '/_adjustFocusAfterTabSwitch\(newTab\) \{/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isSwitchingTab = true;\n          \1/'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' 's/^\{$/{\n  XPCOMUtils.defineLazyServiceGetter(this, "ClipboardHelper", "@mozilla.org\/widget\/clipboardhelper;1", "nsIClipboardHelper");\n  /' \
      's/(this\._textbox\.select\(\);)/\1\n      \n      if(window.fixfx_isOpeningSearch){\n        this.textbox.dispatchEvent(new Event("select"));\n      }/' \
      's/(_setupTextboxEventListeners\(\) \{)/\1\n      this.textbox.addEventListener("select", () => {\n        window.fixfx_isOpeningSearch = false;\n        \n        if(this.value \&\& Services.clipboard.supportsSelectionClipboard()){\n          ClipboardHelper.copyStringToClipboard(this.value, Services.clipboard.kSelectionClipboard);\n        }\n      });\n      /'
    
    if [[ "${settings[options|tabSwitchCopiesToClipboard]-}" ]]; then
      edit_file 'tabSwitchCopiesToClipboard' 'browser_omni' 'modules/UrlbarInput.jsm' 's/^\s*!this\.window\.windowUtils\.isHandlingUserInput \|\|$//'
    else
      edit_file 'tabSwitchCopiesToClipboard' 'browser_omni' 'modules/UrlbarInput.jsm' 's/(_on_select\(event\) \{)/\1\n    if(event?.detail?.fixfx_openingLocationCall){\n      this.window.fixfx_isSwitchingTab = false;\n    }\n    \n    const fixfx_isSwitchingTab = this.window.fixfx_isSwitchingTab;\n    \n    if(this.window.fixfx_isSwitchingTab){\n      this.window.setTimeout(() => this.window.setTimeout(() => this.window.fixfx_isSwitchingTab = false));\n    }\n    /' \
        's/!this\.window\.windowUtils\.isHandlingUserInput \|\|/fixfx_isSwitchingTab ||/'
    fi
    
    if [[ ! "${settings[options|autoCompleteCopiesToClipboard]-}" ]]; then
      edit_file 'autoCompleteCopiesToClipboard' 'browser_omni' 'modules/UrlbarInput.jsm' '/_on_select\(event\) \{/,/ClipboardHelper/ s/(if \(!val)\)/\1 || !this.window.windowUtils.isHandlingUserInput \&\& val !== this.inputField.value \&\& this.inputField.value.endsWith(val))/'
    fi
  fi
  
  if [[ "${settings[options|secondsSeekedByKeyboard]-}" ]]; then
    edit_file 'secondsSeekedByKeyboard' 'omni' 'chrome/toolkit/content/global/elements/videocontrols.js' "s/(newval = oldval [+-] |static SEEK_TIME_SECS = )[0-9]+;/\1${settings[options|secondsSeekedByKeyboard]-};/"
    edit_file 'secondsSeekedByKeyboard' 'omni' 'actors/PictureInPictureChild.jsm' "s/(newval = oldval [+-] |const SEEK_TIME_SECS = )[0-9]+;/\1${settings[options|secondsSeekedByKeyboard]-};/"
  fi
}

prepare_backup_instructions(){
  local -r firefox_dir="${0}"
  
  echo 'You can restore the backup later on by typing these three commands:'
  echo "${formatting[cyan]}cp -p ${backup_targets[omni]@Q} '${firefox_dir}/${unpack_targets[omni]}'"
  echo "cp -p ${backup_targets[browser_omni]@Q} '${firefox_dir}/${unpack_targets[browser_omni]}'"
  echo "touch '${firefox_dir}/browser/.purgecaches'${formatting[reset]}"
  echo "You can also copy the two files in '$(find_backup_dir)' to another backup location."
}

clear_firefox_caches(){
  local -r firefox_dir="${0}"
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
  local -r firefox_dir="${0}"
  local package_key
  
  for package_key in "${!unpack_targets[@]}"; do
    cp --preserve -- "${firefox_dir}/${unpack_targets[${package_key}]}" "${backup_targets[${package_key}]}" \
      && echo "Copying '${firefox_dir}/${unpack_targets[${package_key}]}' to ${backup_targets[${package_key}]@Q}."
  done
  
  echo "Fixing Firefox ${firefox_dir@Q}…"
  
  for package_key in "${!unpack_dirs[@]}"; do
    mkdir -- "${unpack_dirs[${package_key}]}" || terminate '1'
    unzip_without_expected_errors "${firefox_dir}" "${package_key}" || terminate "${?}"
  done
  
  edit_and_lock_based_on_options
  
  for package_key in "${!unpack_dirs[@]}"; do
    (
      cd -- "${unpack_dirs[${package_key}]}" || terminate '1'
      zip -0 --no-dir-entries --quiet --recurse-paths --strip-extra omni.ja -- './'*
    )
    mv -- "${unpack_dirs[${package_key}]}/omni.ja" "${firefox_dir}/${unpack_targets[${package_key}]}" || terminate '1'
    chown --reference="$(dirname -- "${firefox_dir}/${unpack_targets[${package_key}]}")" -- "${firefox_dir}/${unpack_targets[${package_key}]}"
  done
  
  backup_instructions="$(prepare_backup_instructions "${firefox_dir}")"
  clear_firefox_caches "${firefox_dir}"
  echo 'The tweaks should be applied now! Start Firefox and try it out.'
}

offer_backup_restore(){
  local -r firefox_dir="${0}"
  local restore_backup_reply=''
  local package_key
  
  if [[ ! "${settings[quiet]}" && "${is_interactive}" ]]; then
    read -p 'Press [Enter] to exit. Press [r], then [Enter] to restore the backup. ' -r restore_backup_reply
  fi
  
  if [[ "${restore_backup_reply}" =~ [Rr] ]]; then
    for package_key in "${!backup_targets[@]}"; do
      if [[ -f "${backup_targets[${package_key}]}" ]]; then
        cp --preserve -- "${backup_targets[${package_key}]}" "${firefox_dir}/${unpack_targets[${package_key}]}" \
          && echo "Copying ${backup_targets[${package_key}]@Q} to '${firefox_dir}/${unpack_targets[${package_key}]}'."
        clear_firefox_caches "${firefox_dir}"
      else
        echo "The original backup at ${backup_targets[${package_key}]@Q} no longer exists."
      fi
    done
  else
    echo "${backup_instructions}"
  fi
  
  backup_instructions=''
}

assign_backup_target(){
  for package_key in "${!backup_targets[@]}"; do
    backup_targets["${package_key}"]="$(initialize_backup_target "${package_key}")" || terminate "${?}"
  done
  
  echo "Backup locations: ${backup_targets[omni]@Q} and ${backup_targets[browser_omni]@Q}"
}

process_firefox_dirs(){
  local firefox_dir
  local package_key
  
  if (("${#filtered_firefox_dirs[@]}" == 0)); then
    echo "${formatting[red]}Error: No valid Firefox paths found.${formatting[reset]}" >&2
    terminate '1'
  fi
  
  for firefox_dir in "${filtered_firefox_dirs[@]}"; do
    assign_backup_target
    fix_firefox "${firefox_dir}"
    offer_backup_restore "${firefox_dir}"
  done
  
  readonly backup_targets
  readonly backup_instructions
}

apply_options(){
  local enabled_fix_options=()
  local fix_option
  
  # Prepare list of tweaks.
  for fix_option in "${!settings[@]}"; do
    if [[ "${fix_option}" =~ ^options\| && "${settings[${fix_option}]}" ]]; then
      enabled_fix_options+=("${fix_option#options|}$([[ "${settings[${fix_option}]}" != 'on' ]] && echo "=${settings[${fix_option}]}")")
    fi
  done
  
  # Apply -q.
  if [[ "${settings[quiet]}" ]]; then
    needs_confirm_description_read=''
    exec 1>'/dev/null'
  fi
  
  # Display list of tweaks.
  if [[ ! "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    echo "${description}"
    
    if (("${#enabled_fix_options[@]}" == 0)); then
      echo "No tweaks enabled; repack omni.ja without edits"
    else
      echo "Enabled tweak$( (("${#enabled_fix_options[@]}" > 1)) && echo 's'): ${enabled_fix_options[*]@Q}"
    fi
  fi
  
  # Locate backup dir.
  backup_dir="$(find_backup_dir)" || terminate "${?}"
  
  if [[ ! -e "${backup_dir}" ]]; then
    backup_dir="$(dirname -- "${backup_dir}")"
  fi
}

check_write_privileges(){
  if [[ "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    needs_confirm_description_read=''
  fi
  
  if [[ ! "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    echo "Firefox locations: ${filtered_firefox_dirs[*]@Q}"
  fi
  
  root_required_reason="$(check_root_required "${backup_dir}")"
  
  if [[ "${root_required_reason}" && "${root_required_reason}" != "${reason_already_root}" ]]; then
    echo "Continue as root: write access to ${root_required_reason@Q} is required."
    require_root || terminate "${?}"
    terminate '0'
  #elif [[ ! "${settings[quiet]}" && ! "${FIXFX_SWITCHED_TO_ROOT-}" && "${is_interactive}" ]]; then
    # needs_confirm_description_read='true' # TODO: Reconsider where to put this.
  fi
  
  # UX.
  if [[ "${needs_confirm_description_read}" ]]; then
    read -p "Press [Enter] to continue. " -r
  fi
}

trap -- 'terminate 130' 'INT' 'TERM'
set_options "${@}" # settings empty → settings filled
apply_options # `find_backup_dir` might throw → 1>'/dev/null' set, and `find_backup_dir` never throws
collect_firefox_dirs # collected_firefox_dirs empty → collected_firefox_dirs filled
filter_firefox_dirs # filtered_firefox_dirs empty → filtered_firefox_dirs filled
check_write_privileges # root_required_reason empty, FIXFX_SWITCHED_TO_ROOT not set → root_required_reason filled, FIXFX_SWITCHED_TO_ROOT set
process_firefox_dirs
terminate '0'
