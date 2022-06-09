# Firefox `omni.ja` tweaks

A script that directly edits the internal Firefox files stored in the `omni.ja` and `browser/omni.ja` archives to customize the behavior of Firefox such as disabling `clickSelectsAll`, copying automatic URL bar selection to clipboard, etc.

## Where does this script work?

The script works for _me_. 😉
And _I’m_ running Firefox Nightly on Arch Linux.
This is the software setup that I’ve _tested_ — it may work for other setups, too, and this script is likely to work with later versions as well:

<!--
Versions:
pacman -Qi linux gnome-desktop unzip zip
-->

* Firefox Nightly 91.0a1 (2020-07-01) through 91.0a1 (2021-07-06) (64-bit)
<!-- * Firefox ESR 78 (64-bit) (assumed to work, not actually tested yet) -->
* Arch Linux ([`core/linux`][linux] `5.8.1.arch1-1` through `5.12.14.arch1-1`)
* Gnome Desktop ([`extra/gnome-desktop`][gnome-desktop] `1:3.36.5-1` through `1:40.2-1`)
* Bash 4.x+
* Info-ZIP UnZip ([`extra/unzip`][unzip] `6.0-14`)
* Info-ZIP Zip [`extra/zip`][zip] `3.0-9`

_Note: the versions will only be updated for substantial changes to the script._

## How to run the script?

The script applies changes to a specific Firefox install path; it needs to be executed after each update of that Firefox install path.
It should not be executed a second time before another Firefox update.

The script automatically modifies the `omni.ja` file and the `browser/omni.ja` file, and clears the browser’s startup cache and creates a `.purgecaches` file, in order to assure that the changes are properly applied when starting Firefox.

This step-by-step guide describes default script execution, i.e. without any options passed; you can pass [options](#options-in-detail) listed below.

Also see [my Super User answer][super-user] for detailed steps.

### Before using the script for the _first_ time

1. [Download][sh] the script.
2. Set the script as a runnable file.

### Before running the script

3. Update Firefox and start Firefox so it installs all the updates properly.
4. Close Firefox.

### Running the script

5. Execute the script.
   
   * Interactively: Either click it in your file manager, then click the “Run in terminal” button, or run it directly as e.g. `bash ./fixfx.sh`.
   * Non-interactively: Click it in your file manager, then click the “Run” button.
   
   Interactive execution is recommended.
6. The script should find your Firefox (and Firefox ESR) install path(s) automatically.
   If multiple viable paths are found, you can select the one you want to fix.
   If no paths are found, you can either
   
   * call the script with the [`--firefox` option](#options-in-detail), specifying the Firefox install path, or
   * edit the script and put the correct path where it says `Fallback path` (near the top of the script).
   
   The correct path contains a `browser` directory with an `omni.ja` in it.
7. The script checks if you have write access to all relevant directories: the Firefox install path, the backup path, and `/tmp`, where the unzipping happens.
   If not, you’ll be asked to enter your root password.
   You can also run the script with `sudo` instead.
8. A backup of the internal application resources (`omni.ja` and `browser/omni.ja`) of your Firefox installation is created (in `/tmp`, by default).
9. After a few moments, you should be able to launch Firefox normally.
   If everything went well, you should now be able to launch a Firefox with an improved user experience!
   Press <kbd>Enter</kbd> to exit.
10. However, if Firefox won’t run properly, close Firefox, and restore the backup by typing <kbd>r</kbd> and <kbd>Enter</kbd>.
    The backup will be restored and the script will exit.
    Start Firefox again to go back to normal.

Let me know if something went wrong by creating a new issue.
Provide details about terminal output, your system setup, and your software versions.

Since this script partially relies on Firefox making sure to use the newly changed `omni.ja` and `browser/omni.ja`, as opposed to a cached version of these files, additional care must be taken to make issues reproducible.
See the [wiki about the startup cache][wiki-cache] to gain insight into the cache clearing mechanism.

You may some day receive a warning about a pattern failing to match due to the original Firefox code having changed.
Please report these warnings as well.

### Restoring the backup

The script offers an opportunity to test Firefox and restore the backup in case something went wrong.
It also tells you which file paths are being used and tells you the command lines for restoring the backup, if not already applied.

If you need to restore the backup later on, you can type commands into the terminal which are based on the following snippet.
Check if you need to run this as root, and _double-check_ the file paths.

```sh
firefox_dir=$(whereis -b firefox | cut -d ' ' -f 2)          # Or put the correct path here, like the `Fallback path` line in the script.
                                                             # `cut -d ' ' -f 2` just takes the first path found, which may not be the right one.
cp -p /tmp/omni-n.ja~ "$firefox_dir/omni.ja"                 # Replace `n` by the incremental number of the backup file name.
cp -p /tmp/browser_omni-n.ja~ "$firefox_dir/browser/omni.ja" # Replace `n` by the incremental number of the backup file name.
touch "$firefox_dir/browser/.purgecaches"                    # This is necessary only here. A "$firefox_dir/.purgecaches" is ignored.
```

## Options in detail

As usual, short options can be combined, e.g. `-qb '/tmp'` which expands into `-q -b '/tmp'`.
A `--` marks the end of options, meaning every option after that will be ignored.
There are no positional arguments for this script, so in fact, after `--`, _everything_ is ignored.

* `-f DIR`, `--firefox DIR`

  Picks `DIR` as the Firefox install path that is to be fixed.
  
  Note that `DIR` must include a `browser/omni.ja` file. <!-- The script currently really only checks for `browser/omni.ja`, but not `omni.ja`. I could change this, but it’s not strictly necessary. -->
  If this validation fails, the script terminates.
  
  Omit this option to let the script find all `firefox` or `firefox-esr` paths on your system, validate them, and pick the one directory that is found.
  If more than one viable directory is found, the script will ask for selection of a specific directory (unless `-q` or `--quiet` is passed).

* `-o FIX_OPTION`, `--option FIX_OPTION`

  Choose which functionality you want to change in the internal files.
  This flag can be used multiple times.
  
  `FIX_OPTION` can have a few different forms:
  * To turn the option `yourOptionHere` _off_, use `yourOptionHere=` (e.g. `--option preventClickSelectsAll=` or `-o preventClickSelectsAll=`).
  This sets the option entry’s value to an empty string, which acts as a false value in Bash.
  * To turn the option `yourOptionHere` _on_, just type `yourOptionHere` by itself, or with any other substring after `=` (e.g. `-o preventClickSelectsAll` or `-o preventClickSelectsAll=true`).
  * To supply a custom value, use `yourOptionHere=yourValueHere`.
  
  To supply multiple option settings, use the flag multiple times (e.g. `-o optionA= -o optionB`).
  
  See the [available options](#available-options) below.
  Unrecognized options are ignored.

* `-b DIR`, `--backup DIR`

  Stores backup of internal Firefox files `omni.ja` and `browser/omni.ja` in `DIR`.
  
  `DIR` must either point to an existing directory, or its parent directory must exist.
  `DIR` pointing to anything other than a directory is not allowed.
  One directory is automatically created if not yet existing.
  
  Incremental files like `omni-0.ja~`, `omni-1.ja~`, etc., and `browser_omni-0.ja~`, `browser_omni-1.ja~`, etc. are created within that directory.
  
  Omitting this option defaults to backups being stored in `/tmp`.

* `-q`, `--quiet`

  Only errors (specifically, anything echo’d to `STDERR`) will be logged.
  Normal (`STDOUT`) output will be suppressed.
  This will also suppress asking for confirmation.
  
  By default, output will be emitted, but if the script was not executed in an interactive terminal, all interactive selections or confirmation questions are suppressed, regardless of whether the `--quiet` option was passed or not.
  If confirmation questions are suppressed and the script finds more than one viable Firefox install path, it will automatically pick the most recently updated one.
  Note that these tests aren’t perfect and that they can break using some file descriptor redirection, but it should cover most basic cases of executing this script.

* `-h`, `-?`, `--help`, `--?`

  If this option is present, the help information is printed, and the script exits.
  The help text contains contextual information such as the path name of the script source, the default options, etc.

### Available options

| Option flag                                 | Default | Description |
|---------------------------------------------|:-------:|-------------|
| `--option autoCompleteCopiesToClipboard`    |   Off   | Enables selection clipboard as described in `autoSelectCopiesToClipboard`; also enables copying selection in URL bar triggered by typing a URL which is known by the browser (e.g. typing `gi` may autocomplete `github.com`, and the part `thub.com` is selected; the option enables automatically copying this selection to the clipboard). The option `autoCompleteCopiesToClipboard` requires `autoSelectCopiesToClipboard` to be set and is ignored without it. |
| `--option autoSelectCopiesToClipboard`      |   Off   | <p>Certain actions trigger an automatic selection of text in the URL bar or the search bar which aren’t considered user-initiated and as such are not added to the selection clipboard (e.g. selected text which can be inserted with middle-click on Linux) — see <a href="https://bugzilla.mozilla.org/show_bug.cgi?id=1653191">Bugzilla Bug 1653191</a>.</p><p>This option enables clipboard selection for most cases: <kbd>Ctrl</kbd>+<kbd>L</kbd> or <kbd>F6</kbd> for URL bar selection; <kbd>Ctrl</kbd>+<kbd>K</kbd> for search bar selection; <kbd>Esc</kbd> to restore the original URL; <kbd>Tab</kbd> to focus either URL bar or search bar; or single-click or double-click selecting the entire text — if enabled.</p><p>However, additional options must be passed if selection triggered by a tab switch should also be copied (<code>tabSwitchCopiesToClipboard</code>), and if selection triggered by URL auto-complete should be copied (<code>autoCompleteCopiesToClipboard</code>).</p> |
| `--option clearSearchBarOnSubmit`           |   On    | Submitting a search from the separate search bar clears the latter. |
| `--option doubleClickSelectsAll`            |   Off   | Double-clicking the URL bar or the search bar selects the entire input field. |
| `--option preventClickSelectsAll`           |   On    | Clicking the URL bar or the search bar no longer selects the entire input field. |
| `--option secondsSeekedByKeyboard=`_number_ |         | Pressing <kbd>←</kbd> or <kbd>→</kbd> in the built-in video player (including Picture-in-Picture mode) seeks by _number_ seconds. Fixes [Bugzilla Bug 1668692](https://bugzilla.mozilla.org/show_bug.cgi?id=1668692) which asks for the seek interval to be changed from 15 seconds to 5 seconds. The equivalent option would be `-o secondsSeekedByKeyboard=5`. |
| `--option tabSwitchCopiesToClipboard`       |   Off   | Enables copying selection in URL bar triggered by switching to a tab with a focused URL bar (with either clicking or with <kbd>Ctrl</kbd>+(<kbd>Shift</kbd>)+<kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>Page Up</kbd>, <kbd>Ctrl</kbd>+<kbd>Page Down</kbd>, <kbd>Alt</kbd>+<kbd>1</kbd>..<kbd>9</kbd>, and possibly other ways). The option `tabSwitchCopiesToClipboard` requires `autoSelectCopiesToClipboard` to be set and is ignored without it. |

### Examples

We’ll assume that the script is callable via `./fixfx.sh`.
The exact path and file name depends on where you placed the file.

* The following command fixes a specific Firefox installation located under `/usr/lib/firefox-de_DE` and creates an incremental backup of the original `omni.ja` in `/tmp`.
  The specified directory must contain a `browser/omni.ja`.

  ```sh
  ./fixfx.sh --firefox /usr/lib/firefox-de_DE
  ```

* This command fixes an automatically determined Firefox installation, while creating a backup of `omni.ja` and `browser/omni.ja` in the specified directory.
  The file names are incremental, e.g. `omni-0.ja~`, `omni-1.ja~`, etc.

  ```sh
  ./fixfx.sh -b /home/user/backups/my_firefox_backups
  ```

* This command enables the behavior where double-clicking a URL bar selects the entire URL, but not a single click.
  
  ```sh
  ./fixfx.sh -o preventClickSelectsAll -o doubleClickSelectsAll
  ```
  
  If you want _both_ click behaviors and `preventClickSelectsAll` is the default in your script (see `./fixfx.sh -h` to check), use this instead:
  
  ```sh
  ./fixfx.sh -o preventClickSelectsAll= -o doubleClickSelectsAll
  ```

## Exit status

The script distinguishes between four different status codes when exiting.
Error codes (i.e. status codes greater than 0) are usually accompanied by an error message printed to `STDERR`.

* `0` for success: everything went as expected, the script terminated successfully.
* `1` for general failure due to utilities used in the script: e.g. some file was not found, some directory could not be created, directory navigation failed, unzipping or zipping the `omni.ja` failed, read or write permissions could not be granted, etc.
* `2` for incorrect script usage: e.g. `--backup`, `--firefox`, or `--option` used without values, the specified Backup directory isn’t an existing directory, the specified Firefox path is not a valid Firefox path, etc.
* `130` if the script process was terminated (e.g. via <kbd>Ctrl</kbd>+<kbd>C</kbd>) or killed.

---

## A brief history of the scope of this repository

See [this answer on Super User][super-user] for full context and an explanation of the script.
The repo’s URL used to be `https://github.com/SebastianSimon/firefox-selection-fix`.

Various browsers have started adopting a particular behavior when clicking the address bar: the entire URL is selected.
This goes against good UX practices.
In Firefox, there used to be the preferences `browser.urlbar.clickSelectsAll`, `browser.urlbar.update1`, and `browser.urlbar.update2` to control this behavior and other updates, but the latter two were always expected to be temporary.

Around March 2020, the [`browser.urlbar.clickSelectsAll` preference has been removed][regression-bug].
Since then, this bug has been [under discussion][bug], where a patch has been suggested — this would involve recompiling Firefox from scratch.
As the _“`clickSelectsAll` doesn’t work”_ duplicates accumulate on Bugzilla to this day, one of these has received a [comment by Stephen McCarthy][bugzilla-workaround] which describes a workaround that involves editing internal Firefox files.
This workaround looks like the simplest approach, but the approach didn’t work as-is.

This repo provides a script that attempts to give us users the `browser.urlbar.clickSelectsAll = false` experience back.

I realized the potential of this script: it could also be used to change _any_ aspect of Firefox’s behavior, not just this selection behavior.
Indeed, several months later, some users have requested a few other features, so I started including new features and customization options.
Since then, the repo has been renamed to its current name.


  [super-user]: https://superuser.com/a/1559926/751213
  [regression-bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=333714
  [bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=1621570
  [bugzilla-workaround]: https://bugzilla.mozilla.org/show_bug.cgi?id=1643973#c6
  [sh]: https://raw.githubusercontent.com/SebastianSimon/firefox-omni-tweaks/master/fixfx.sh
  [linux]: https://www.archlinux.org/packages/core/x86_64/linux/
  [gnome-desktop]: https://www.archlinux.org/packages/extra/x86_64/gnome-desktop/
  [unzip]: https://www.archlinux.org/packages/extra/x86_64/unzip/
  [zip]: https://www.archlinux.org/packages/extra/x86_64/zip/
  [wiki-cache]: https://github.com/SebastianSimon/firefox-omni-tweaks/wiki/Careful-considerations-concerning-clearing-cache
