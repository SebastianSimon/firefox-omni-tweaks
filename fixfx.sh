#!/bin/bash
# shellcheck disable=SC2155

# Script repo: https://github.com/SebastianSimon/firefox-omni-tweaks

set -o 'nounset'

readonly description='The FixFx script tweaks Firefox. Make sure Firefox is up-to-date and closed.'
readonly reason_already_root='already_root'
readonly absolute_bash_source="$(readlink --canonicalize -- "${BASH_SOURCE[0]}")"
is_interactive=''
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
  [backupDir]='/tmp'
  [fixOnlyYoungest]=''
  [options|autoCompleteCopiesToClipboard]=''
  [options|autoSelectCopiesToClipboard]=''
  [options|clearSearchBarOnSubmit]=''
  [options|doubleClickSelectsAll]=''
  [options|preventClickSelectsAll]='on'
  [options|secondsSeekedByKeyboard]=''
  [options|tabSwitchCopiesToClipboard]=''
  [options|viewImageInCurrentTab]=''
  [quiet]=''
  # End presets.
)
declare -A backup_targets=(
  [omni]=''
  [browser_omni]=''
)
needs_confirm_description_read='true'
backup_instructions=''
declare -A collected_firefox_dirs=()
filtered_firefox_dirs=()
explicit_script_params=()

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
  echo "
Usage: ${BASH_SOURCE[0]} [OPTION...]
OPTIONs '-f', '--firefox', '-b', and '--backup' need a DIR value.
OPTIONs '-o' and '--option' need a FIX_OPTION value.
Type '${BASH_SOURCE[0]} --help' for more information."
}

fix_option_default_value(){
  local -r fix_key="${1}"
  
  case "${fix_key}" in
    'autoCompleteCopiesToClipboard' | 'autoSelectCopiesToClipboard' | 'clearSearchBarOnSubmit' | 'doubleClickSelectsAll' | 'preventClickSelectsAll' | 'tabSwitchCopiesToClipboard' | 'viewImageInCurrentTab')
      echo 'on'
      ;;
    *)
      echo ''
  esac
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
                               collection that needs fixing. Can be used
                               multiple times.
  
  -a, --add-all-found        Automatically find all Firefox (ESR) install paths
                               and add them to the collection that needs
                               fixing.
  
  -y, --fix-only-youngest    Pick only the youngest Firefox (ESR) install path
                               from the collection, i.e. latest modification /
                               install date, to be fixed.
  
  -o FIX_OPTION,             Choose which tweak to apply to omni.ja. FIX_OPTION
  --option FIX_OPTION          is 'FIX_OPTION_KEY' or 'FIX_OPTION_KEY=' to
                               turn a tweak on or off, respectively;
                               FIX_OPTION can also be 'FIX_OPTION_KEY=VALUE',
                               if a FIX_OPTION_KEY requires a specific VALUE.
                               Can be used multiple times.
  
  -b DIR, --backup DIR       Store backup of internal Firefox files 'omni.ja'
                               and 'browser/omni.ja' in DIR; directory is
                               created if it doesn’t exist, but parent
                               directory must exist; default: ${settings[backupDir]@Q}.
  
  -q, --quiet                Do not log every step; do not ask for
                               confirmation.
  
  -h, -?, --help, --?        Show this help and exit.

FIX_OPTION_KEYs:
  autoCompleteCopiesToClipboard
                             Requires autoSelectCopiesToClipboard. Also copies
                               selection to clipboard when auto-completing
                               URLs; ${settings[options|autoCompleteCopiesToClipboard]:-off} by default.
  
  autoSelectCopiesToClipboard
                             Copy selection to clipboard always when text in
                               the URL bar or search bar is selected, e.g.
                               when pressing [Ctrl] + [L] or [F6], but not
                               when switching tabs or when auto-completing
                               URLs; ${settings[options|autoSelectCopiesToClipboard]:-off} by default.
  
  clearSearchBarOnSubmit     Submitting a search from the separate search bar
                               clears its content; ${settings[options|clearSearchBarOnSubmit]:-off} by default.
  
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

  viewImageInCurrentTab      Right clicking on an image (or video) shows an
                               option \"view image\" or \"view video\" which
                               opens the video or image in the current tab,
                               unless middle clicked, or pressed with either
                               ctrl or shift held down. The context menu label
                               is currently only renamed for english locales,
                               but the functionality works on all locales.

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
  
  while [[ -v settings["firefoxDirs|${firefox_dirs_count}"] ]]; do
    ((firefox_dirs_count++))
  done
  
  while (("${#}" > 0)); do
    if combined_short_options "${1}"; then
      set -- "${1:0:2}" "$(separate_flag_option_with_hyphen "${1:0:2}")${1:2}" "${@:2}"
    fi
    
    assert_key_option_has_value "${@}" || {
      echo "${formatting[red]}Error: No value provided for option ${1@Q}.${formatting[reset]}" >&2
      show_usage
      terminate '2'
    }
    
    case "${1}" in
      '--')
        break
        ;;
      '-b' | '--backup')
        if [[ ! "${2}" ]]; then
          echo "${formatting[red]}Error: Backup path cannot be empty.${formatting[reset]}" >&2
          show_usage
          terminate '2'
        fi
        
        settings[backupDir]="${2}"
        shift
        ;;
      '-f' | '--firefox')
        settings["firefoxDirs|${firefox_dirs_count}"]="${2}"
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

check_interactive(){
  if [[ -t 1 ]]; then
    is_interactive='true'
  fi

  readonly is_interactive

  if [[ ! "${is_interactive}" ]]; then
    needs_confirm_description_read=''
  fi
}

apply_quiet(){
  if [[ "${settings[quiet]}" ]]; then
    needs_confirm_description_read=''
    exec 1>'/dev/null'
  fi
}

show_tweaks(){
  local enabled_fix_options=()
  local fix_option

  for fix_option in "${!settings[@]}"; do
    if [[ "${fix_option}" =~ ^options\| && "${settings[${fix_option}]}" ]]; then
      enabled_fix_options+=("${fix_option#options|}$([[ "${settings[${fix_option}]}" != 'on' ]] && echo "=${settings[${fix_option}]}")")
    fi
  done
  
  if [[ ! "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    echo "${description}"
    
    if (("${#enabled_fix_options[@]}" == 0)); then
      echo "No tweaks enabled; repack omni.ja and browser/omni.ja without edits."
    else
      echo "Enabled tweak$( (("${#enabled_fix_options[@]}" > 1)) && echo 's'): ${enabled_fix_options[*]@Q}."
    fi
  fi
}

apply_options(){
  check_interactive
  apply_quiet
  show_tweaks
}

collect_specified(){
  local firefox_dirs_count='0'
  
  while [[ -v settings["firefoxDirs|${firefox_dirs_count}"] ]]; do
    if [[ "${settings["firefoxDirs|${firefox_dirs_count}"]}" && -f "${settings["firefoxDirs|${firefox_dirs_count}"]}/omni.ja" && -f "${settings["firefoxDirs|${firefox_dirs_count}"]}/browser/omni.ja" ]]; then
      collected_firefox_dirs["${settings["firefoxDirs|${firefox_dirs_count}"]}"]='1'
    else
      echo "${formatting[yellow]}Warning: ${settings["firefoxDirs|${firefox_dirs_count}"]@Q} is not a Firefox installation path.${formatting[reset]}" >&2
    fi
    
    ((firefox_dirs_count++))
  done
}

collect_found(){
  local found_firefox_dir
  local found_firefox_dirs

  if [[ ! "${is_interactive}" || "${settings[addAllFound]}" || ! -v settings['firefoxDirs|0'] ]]; then
    mapfile -t found_firefox_dirs < <(printf "%s" "$(whereis -b 'firefox' 'firefox-esr' | sed --regexp-extended --expression='s/^.*?:\s*//g' | xargs | tr ' ' '\n')")
    
    for found_firefox_dir in "${found_firefox_dirs[@]}"; do
      if [[ -f "${found_firefox_dir}/omni.ja" && -f "${found_firefox_dir}/browser/omni.ja" ]]; then
        collected_firefox_dirs["${found_firefox_dir}"]='1'
      fi
    done
  fi
}

collect_firefox_dirs(){
  collect_specified
  collect_found
}

filter_only_youngest(){
  local most_recently_updated
  local current_firefox_dir=''
  
  for most_recently_updated in "${!collected_firefox_dirs[@]}"; do
    if [[ "${most_recently_updated}/browser/omni.ja" -nt "${current_firefox_dir}/browser/omni.ja" ]]; then
      current_firefox_dir="${most_recently_updated}"
    fi
  done
  
  if (("${#collected_firefox_dirs[@]}" > 0)); then
    filtered_firefox_dirs+=("${current_firefox_dir}")
  fi
}

filter_include_all(){
  local collected_firefox_dir
  
  for collected_firefox_dir in "${!collected_firefox_dirs[@]}"; do
    filtered_firefox_dirs+=("$(readlink --canonicalize -- "${collected_firefox_dir}")")
  done
}

filter_multiple_choice(){
  local collected_firefox_dir
  local firefox_choices
  local firefox_reply
  local chosen_firefox_indexes
  local chosen_firefox_index
  
  while (("${#filtered_firefox_dirs[@]}" == 0)); do
    echo 'Multiple Firefox install paths found. Type numbers to choose paths; leave empty to choose all. Non-numbers are ignored.'
    firefox_choices=()
    
    for collected_firefox_dir in "${!collected_firefox_dirs[@]}"; do
      firefox_choices+=("${collected_firefox_dir}")
      echo "$(printf %2s "${#firefox_choices[@]}"): ${collected_firefox_dir}"
    done
    
    read -p 'Choose: ' -r firefox_reply
    mapfile -t chosen_firefox_indexes < <(grep --extended-regexp '[0-9]+' --only-matching <<< "${firefox_reply}")
    
    if (("${#chosen_firefox_indexes[@]}" == 0)); then
      filter_include_all
    else
      for chosen_firefox_index in "${chosen_firefox_indexes[@]}"; do
        if (("${chosen_firefox_index}" < 1 || "${chosen_firefox_index}" > "${#collected_firefox_dirs[@]}")); then
          echo "${formatting[yellow]}Warning: ${chosen_firefox_index@Q} is not a valid choice.${formatting[reset]}" >&2
        else
          filtered_firefox_dirs+=("${firefox_choices["$(("${chosen_firefox_index}" - 1))"]}")
        fi
      done
      
      if (("${#filtered_firefox_dirs[@]}" == 0)); then
        echo "${formatting[yellow]}Warning: Could not receive a valid choice. Try again or press [Ctrl] + [C] to cancel.${formatting[reset]}" >&2
      fi
    fi
  done
}

filter_firefox_dirs(){
  if [[ "${settings[fixOnlyYoungest]}" ]]; then
    filter_only_youngest
  elif [[ "${is_interactive}" && ! "${settings[addAllFound]}" && ! -v settings['firefoxDirs|0'] && ! "${settings[quiet]}" ]] && (("${#collected_firefox_dirs[@]}" > 1)); then
    needs_confirm_description_read=''
    filter_multiple_choice
  else
    filter_include_all
  fi
}

find_backup_dir(){
  if [[ ! -e "${settings[backupDir]}" && -d "$(dirname -- "${settings[backupDir]}")" || -d "${settings[backupDir]}" ]]; then
    readlink --canonicalize -- "${settings[backupDir]}"
  else
    echo "${formatting[red]}Error: ${settings[backupDir]@Q} has no parent directory or is not a directory itself.${formatting[reset]}" >&2
    
    return '2'
  fi
}

check_write_privileges(){
  declare -A checked_directories=()
  local firefox_dir
  local package_key
  local path
  
  if [ "$(id --user)" -eq '0' ]; then
    echo "${reason_already_root}"
    
    return
  fi
  
  for package_key in 'omni' 'browser_omni'; do
    path="$(dirname -- "${unpack_dirs[${package_key}]}")"
    checked_directories["$(readlink --canonicalize -- "${path}")"]='checked'
  
    for firefox_dir in "${filtered_firefox_dirs[@]}"; do
      for path in "$(dirname -- "${firefox_dir}/${unpack_targets[${package_key}]}")" "${firefox_dir}/${unpack_targets[${package_key}]}"; do
        checked_directories["$(readlink --canonicalize -- "${path}")"]='checked'
      done
    done
  done
  
  for path in "${@}"; do
    checked_directories["$(readlink --canonicalize -- "${path}")"]='checked'
  done
  
  for path in "${!checked_directories[@]}"; do
    if [[ ! -w "${path}" ]]; then
      echo "${path}"
      
      return
    fi
  done
}

get_options(){
  local filtered_firefox_dir
  local fix_option
  
  explicit_script_params+=('-b' "${settings[backupDir]}")
  
  for filtered_firefox_dir in "${filtered_firefox_dirs[@]}"; do
    explicit_script_params+=('-f' "${filtered_firefox_dir}")
  done
  
  for fix_option in 'autoCompleteCopiesToClipboard' 'autoSelectCopiesToClipboard' 'clearSearchBarOnSubmit' 'doubleClickSelectsAll' 'preventClickSelectsAll' 'secondsSeekedByKeyboard' 'tabSwitchCopiesToClipboard' 'viewImageInCurrentTab'; do
    explicit_script_params+=('-o' "${fix_option}=${settings[options|${fix_option}]}")
  done
  
  if [[ "${settings[quiet]}" ]]; then
    explicit_script_params+=('-q')
  fi
}

require_root(){
  if [ "$(id --user)" -ne '0' ]; then
    get_options
    sudo 'env' FIXFX_SWITCHED_TO_ROOT='true' "${absolute_bash_source}" "${explicit_script_params[@]}"
  fi
}

prepare_processing(){
  local backup_dir=''
  
  if (("${#filtered_firefox_dirs[@]}" == 0)); then
    echo "${formatting[red]}Error: No valid Firefox paths found.${formatting[reset]}" >&2
    terminate '2'
  fi
  
  if [[ "${FIXFX_SWITCHED_TO_ROOT-}" ]]; then
    needs_confirm_description_read=''
  else
    echo "Firefox location$( (("${#filtered_firefox_dirs[@]}" > 1)) && echo 's'): ${filtered_firefox_dirs[*]@Q}."
  fi
  
  backup_dir="$(find_backup_dir)" || terminate "${?}"
  
  if [[ ! -e "${backup_dir}" ]]; then
    backup_dir="$(dirname -- "${backup_dir}")"
  fi
  
  readonly backup_dir
  root_required_reason="$(check_write_privileges "${backup_dir}")"
  
  if [[ "${root_required_reason}" && "${root_required_reason}" != "${reason_already_root}" ]]; then
    echo "Continue as root: write access to ${root_required_reason@Q} is required."
    require_root || terminate "${?}"
    terminate '0'
  fi
  
  if [[ "${needs_confirm_description_read}" ]]; then
    read -p "Press [Enter] to continue. " -r
  fi
}

initialize_backup_target(){
  local prefix="${1}"
  local -r start="${settings[backupDir]}/${prefix}-"
  local -r end='.ja~'
  local incremental_number='0'
  
  if [[ ! -e "${settings[backupDir]}" && -d "$(dirname -- "${settings[backupDir]}")" ]]; then
    mkdir "${settings[backupDir]}"
  fi
  
  find_backup_dir 1>'/dev/null' || return "${?}"
  
  while ! (
    set -o noclobber
    echo -n '' >"${start}${incremental_number}${end}"
  ) 2>'/dev/null'; do
    ((incremental_number++))
  done
  
  readlink --canonicalize -- "${start}${incremental_number}${end}"
}

assign_backup_target(){
  for package_key in "${!backup_targets[@]}"; do
    backup_targets["${package_key}"]="$(initialize_backup_target "${package_key}")" || terminate "${?}"
  done
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
    echo "${formatting[yellow]}Warning: unexpected warning(s) or error(s) in unzip:" >&2
    echo "${unzip_errors}${formatting[reset]}" >&2
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

edit_and_lock_based_on_options(){
  local urlbarinput_path='modules/UrlbarInput.sys.mjs'
  
  if [[ ! -f "${unpack_dirs['browser_omni']}/${urlbarinput_path}" ]]; then
    urlbarinput_path='modules/UrlbarInput.jsm'
  fi
  
  readonly urlbarinput_path
  
  if [[ "${settings[options|preventClickSelectsAll]-}" ]]; then
    edit_file 'preventClickSelectsAll' 'browser_omni' "${urlbarinput_path}" 's/(this\._preventClickSelectsAll = )this\.focused;/\1true;/'
    edit_file 'preventClickSelectsAll' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' 's/(this\._preventClickSelectsAll = )this\._textbox\.focused;/\1true;/'
  fi
  
  if [[ "${settings[options|clearSearchBarOnSubmit]-}" ]]; then
    edit_file 'clearSearchBarOnSubmit' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' '/openTrustedLinkIn/s/$/textBox.value = "";/'
  fi
  
  if [[ "${settings[options|doubleClickSelectsAll]-}" ]]; then
    edit_file 'doubleClickSelectsAll' 'browser_omni' "${urlbarinput_path}" 's/(if \(event\.target\.id == SEARCH_BUTTON_ID\) \{)/if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        } else \1/'
    edit_file 'doubleClickSelectsAll' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' '/this\.addEventListener\("mousedown", event => \{/,/\}\);/ s/(\}\);)/        \n        if (event.detail === 2) {\n          this.select();\n          event.preventDefault();\n        }\n      \1/'
  fi
  
  if [[ "${settings[options|autoSelectCopiesToClipboard]-}" ]]; then
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' "${urlbarinput_path}" 's/(_on_select\(event\) \{)/\1\n    this.window.fixfx_isOpeningLocation = false;\n    /' \
      's/(this\._suppressPrimaryAdjustment = )true;/\1false;/' \
      's/(this\.inputField\.select\(\);)/\1\n    \n    if(this.window.fixfx_isOpeningLocation){\n      this._on_select({\n        detail: {\n          fixfx_openingLocationCall: true\n        }\n      });\n    }\n    /'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/browser.js' '/function openLocation/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isOpeningLocation = true;\n    \1/' \
      's/^(\s*searchBar\.select\(\);)$/      window.fixfx_isOpeningSearch = true;\n\1/'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/tabbrowser.js' '/_adjustFocusAfterTabSwitch\(newTab\) \{/,/gURLBar\.select\(\);/ s/(gURLBar\.select\(\);)/window.fixfx_isSwitchingTab = true;\n          \1/'
    edit_file 'autoSelectCopiesToClipboard' 'browser_omni' 'chrome/browser/content/browser/search/searchbar.js' 's/^\{$/{\n  XPCOMUtils.defineLazyServiceGetter(this, "ClipboardHelper", "@mozilla.org\/widget\/clipboardhelper;1", "nsIClipboardHelper");\n  /' \
      's/(this\._textbox\.select\(\);)/\1\n      \n      if(window.fixfx_isOpeningSearch){\n        this.textbox.dispatchEvent(new Event("select"));\n      }/' \
      's/(_setupTextboxEventListeners\(\) \{)/\1\n      this.textbox.addEventListener("select", () => {\n        window.fixfx_isOpeningSearch = false;\n        \n        if(this.value \&\& Services.clipboard.supportsSelectionClipboard()){\n          ClipboardHelper.copyStringToClipboard(this.value, Services.clipboard.kSelectionClipboard);\n        }\n      });\n      /'
    
    if [[ "${settings[options|tabSwitchCopiesToClipboard]-}" ]]; then
      edit_file 'tabSwitchCopiesToClipboard' 'browser_omni' "${urlbarinput_path}" 's/^\s*!this\.window\.windowUtils\.isHandlingUserInput \|\|$//'
    else
      edit_file 'tabSwitchCopiesToClipboard' 'browser_omni' "${urlbarinput_path}" 's/(_on_select\(event\) \{)/\1\n    if(event?.detail?.fixfx_openingLocationCall){\n      this.window.fixfx_isSwitchingTab = false;\n    }\n    \n    const fixfx_isSwitchingTab = this.window.fixfx_isSwitchingTab;\n    \n    if(this.window.fixfx_isSwitchingTab){\n      this.window.setTimeout(() => this.window.setTimeout(() => this.window.fixfx_isSwitchingTab = false));\n    }\n    /' \
        's/!this\.window\.windowUtils\.isHandlingUserInput \|\|/fixfx_isSwitchingTab ||/'
    fi
    
    if [[ ! "${settings[options|autoCompleteCopiesToClipboard]-}" ]]; then
      edit_file 'autoCompleteCopiesToClipboard' 'browser_omni' "${urlbarinput_path}" '/_on_select\(event\) \{/,/ClipboardHelper/ s/(if \(!val)\)/\1 || !this.window.windowUtils.isHandlingUserInput \&\& val !== this.inputField.value \&\& this.inputField.value.endsWith(val))/'
    fi
  fi
  
  if [[ "${settings[options|secondsSeekedByKeyboard]-}" ]]; then
    edit_file 'secondsSeekedByKeyboard' 'omni' 'chrome/toolkit/content/global/elements/videocontrols.js' "s/(newval = oldval [+-] |static SEEK_TIME_SECS = )[0-9]+;/\1${settings[options|secondsSeekedByKeyboard]-};/"
    edit_file 'secondsSeekedByKeyboard' 'omni' 'actors/PictureInPictureChild.jsm' "s/(newval = oldval [+-] |const SEEK_TIME_SECS = )[0-9]+;/\1${settings[options|secondsSeekedByKeyboard]-};/"
  fi

  if [[ "${settings[options|viewImageInCurrentTab]-}" ]]; then
    # first edit the JS responsible
    edit_file 'viewImageInCurrentTab' 'browser_omni' 'chrome/browser/content/browser/nsContextMenu.sys.mjs' 's!where = "tab";!// where = "tab";!'
    # gotta hit any possible locales, but this script has no provisions for
    # other languages. So this will hit en-GB and en-US (among others)
    # correctly and should not break non-english locales.
    echo 'Note: if your locale is not English, this will fail to relabel the "open image'
    echo 'in new tab" button, but it will still function properly. Patches welcome.'
    # doing working directory juggling to get the 'for' loop to give the
    # appropriate names for the edit_file function.
    # see firefox-l10n repository history for other locales' labels
    OLDWD="$(pwd)"
    pushd "${unpack_dirs['browser_omni']}"'/localization' > /dev/null
    # only process english locales for now, but please add your own for loop(s) for your locale(s)
    for file in en-*; do
      # not sure working directory matters but trying to tamper with this
      # script as little as possible
      cd "$OLDWD"
      edit_file 'viewImageInCurrentTab' 'browser_omni' 'localization/'"$file"'/browser/browserContext.ftl' 's/\.label = Open Image in New Tab/\.label = View Image/;s/\.label = Open Video in New Tab/\.label = View Video/'
    done
    popd > /dev/null
  fi

}

prepare_backup_instructions(){
  local -r firefox_dir="${1}"
  
  echo 'You can restore the backup later on by typing these three commands:'
  echo "${formatting[cyan]}cp -p '$(readlink --canonicalize -- "${backup_targets[omni]}")' '$(readlink --canonicalize -- "${firefox_dir}/${unpack_targets[omni]}")'"
  echo "cp -p '$(readlink --canonicalize -- "${backup_targets[browser_omni]}")' '$(readlink --canonicalize -- "${firefox_dir}/${unpack_targets[browser_omni]}")'"
  echo "touch '${firefox_dir}/browser/.purgecaches'${formatting[reset]}"
  echo "You can also copy the two files in '$(find_backup_dir)' to another backup location."
}

clear_firefox_caches(){
  local -r firefox_dir="${1}"
  local -r cache_dir="$(getent passwd "${SUDO_USER:-${USER}}" | cut --delimiter=':' --fields='6')/.cache/mozilla/firefox"
  local startup_cache
  
  if [[ -d "${cache_dir}" ]]; then
    shopt -s 'nullglob'
    
    for startup_cache in "${cache_dir}/"*'/startupCache'; do
      rm --recursive --force -- "${startup_cache}" 2>'/dev/null' \
        && echo "Clearing startup cache in '$(readlink --canonicalize -- "$(dirname -- "${startup_cache}")")'."
    done
    
    shopt -u 'nullglob'
  fi
  
  touch -- "${firefox_dir}/browser/.purgecaches" \
    && chown --reference="${firefox_dir}/browser" -- "${firefox_dir}/browser/.purgecaches"
}

fix_firefox(){
  local -r firefox_dir="${1}"
  local package_key
  local unpack_target
  local backup_target
  
  for package_key in "${!unpack_targets[@]}"; do
    unpack_target="$(readlink --canonicalize -- "${firefox_dir}/${unpack_targets[${package_key}]}")"
    backup_target="$(readlink --canonicalize -- "${backup_targets[${package_key}]}")"
    cp --preserve -- "${unpack_target}" "${backup_target}" \
      && echo "Copying ${unpack_target@Q} to ${backup_target@Q}."
  done
  
  echo "Fixing Firefox ${firefox_dir@Q}."
  
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
  local -r firefox_dir="${1}"
  local restore_backup_reply=''
  local package_key
  local backup_target
  local unpack_target
  
  if [[ ! "${settings[quiet]}" && "${is_interactive}" ]]; then
    read -p 'Press [Enter] to exit. Press [r], then [Enter] to restore the backup. ' -r restore_backup_reply
  fi
  
  if [[ "${restore_backup_reply}" =~ [Rr] ]]; then
    for package_key in "${!backup_targets[@]}"; do
      if [[ -f "${backup_targets[${package_key}]}" ]]; then
        backup_target="$(readlink --canonicalize -- "${backup_targets[${package_key}]}")"
        unpack_target="$(readlink --canonicalize -- "${firefox_dir}/${unpack_targets[${package_key}]}")"
        cp --preserve -- "${backup_target}" "${firefox_dir}/${unpack_targets[${package_key}]}" \
          && echo "Copying ${backup_target@Q} to ${unpack_target@Q}."
        clear_firefox_caches "${firefox_dir}"
      else
        echo "The original backup at ${backup_target@Q} no longer exists."
      fi
    done
  else
    echo "${backup_instructions}"
  fi
  
  backup_instructions=''
}

process_firefox_dirs(){
  local firefox_dir
  local package_key
  
  for firefox_dir in "${filtered_firefox_dirs[@]}"; do
    assign_backup_target
    fix_firefox "${firefox_dir}"
    offer_backup_restore "${firefox_dir}"
    cleanup
    echo
  done
  
  readonly backup_targets
  readonly backup_instructions
}

trap -- 'terminate 130' 'INT' 'TERM'
set_options "${@}"
apply_options
collect_firefox_dirs
filter_firefox_dirs
prepare_processing
process_firefox_dirs
terminate '0'
