#!/bin/bash

readonly test_firefox_source="${1}"

if [[ -z "${test_firefox_source}" ]]; then
  echo 'Usage: ./test.sh FIREFOX_DIR'

  exit '1'
fi

print_failed(){
  echo "$(tput setaf 1)⏺ FAILED$(tput sgr0): ${1}"
}

print_passed(){
  echo "$(tput setaf 2)⏺ PASSED$(tput sgr0): ${1}"
}

test_all_options_produce_no_warnings(){
  local -r test_name='All options enabled will not produce warnings'
  local -r test_dir='./test/allOptions'

  mkdir --parents -- "${test_dir}"
  cp --recursive -- "${test_firefox_source}"/* "${test_dir}"

  ./fixfx.sh --firefox "${test_dir}" --option 'autoCompleteCopiesToClipboard' --option 'autoSelectCopiesToClipboard' --option 'clearSearchBarOnSubmit' --option 'doubleClickSelectsAll' --option 'preventClickSelectsAll' --option 'secondsSeekedByKeyboard=10' --option 'tabSwitchCopiesToClipboard' --quiet 2>"${test_dir}.stderr"

  if [[ -n "$(cat "${test_dir}.stderr")" ]]; then
    print_failed "“${test_name}”; warnings produced:"
    cat "${test_dir}.stderr"

    return '1'
  fi

  print_passed "${test_name}"
}

test_all_options_except_tab_switch_copies_to_clipboard_produce_no_warnings(){
  local -r test_name='All options, but tabSwitchCopiesToClipboard off, will not produce warnings'
  local -r test_dir='./test/allOptionsWithoutTabSwitchCopiesToClipboard'

  mkdir --parents -- "${test_dir}"
  cp --recursive -- "${test_firefox_source}"/* "${test_dir}"

  ./fixfx.sh --firefox "${test_dir}" --option 'autoCompleteCopiesToClipboard' --option 'autoSelectCopiesToClipboard' --option 'clearSearchBarOnSubmit' --option 'doubleClickSelectsAll' --option 'preventClickSelectsAll' --option 'secondsSeekedByKeyboard=10' --option 'tabSwitchCopiesToClipboard=' --quiet 2>"${test_dir}.stderr"

  if [[ -n "$(cat "${test_dir}.stderr")" ]]; then
    print_failed "“${test_name}”; warnings produced:"
    cat "${test_dir}.stderr"

    return '1'
  fi

  print_passed "${test_name}"
}

test_all_options_produce_no_warnings
test_all_options_except_tab_switch_copies_to_clipboard_produce_no_warnings
rm --recursive -- './test'
