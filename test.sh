#!/bin/bash
# shellcheck disable=SC1111

readonly test_firefox_source="${1}"
test_status='0'

set_failed(){
  test_status='1'
}

if [[ -z "${test_firefox_source}" ]]; then
  echo 'Usage: ./test.sh FIREFOX_DIR'

  exit '2'
fi

print_failed(){
  echo "$(tput setaf 1)⏺ FAILED$(tput sgr0): ${1}"
}

print_passed(){
  echo "$(tput setaf 2)⏺ PASSED$(tput sgr0): ${1}"
}

test_test_script_passes_shellcheck(){
  local -r test_name='Test script passes ShellCheck'
  local -r test_dir='./test/test_shellcheck'

  mkdir --parents -- "${test_dir}"
  cp --recursive -- "${test_firefox_source}"/* "${test_dir}"

  shellcheck --color=always ./test.sh >"${test_dir}.stdout"

  if [[ -n "$(cat "${test_dir}.stdout")" ]]; then
    print_failed "“${test_name}”; output:"
    cat "${test_dir}.stdout"

    return '1'
  fi

  print_passed "${test_name}"
}

test_fixfx_script_passes_shellcheck(){
  local -r test_name='FixFx script passes ShellCheck'
  local -r test_dir='./test/fixfx_shellcheck'

  mkdir --parents -- "${test_dir}"
  cp --recursive -- "${test_firefox_source}"/* "${test_dir}"

  shellcheck --color=always ./fixfx.sh >"${test_dir}.stdout"

  if [[ -n "$(cat "${test_dir}.stdout")" ]]; then
    print_failed "“${test_name}”; output:"
    cat "${test_dir}.stdout"

    return '1'
  fi

  print_passed "${test_name}"
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

test_test_script_passes_shellcheck || set_failed
test_fixfx_script_passes_shellcheck || set_failed
test_all_options_produce_no_warnings || set_failed
test_all_options_except_tab_switch_copies_to_clipboard_produce_no_warnings || set_failed
rm --recursive -- './test'

exit "${test_status}"
