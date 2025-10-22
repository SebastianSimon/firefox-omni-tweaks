# Firefox `omni.ja` tweaks

A script that directly edits the internal Firefox files stored in the `omni.ja` and `browser/omni.ja` archives to customize the behavior of Firefox such as disabling `clickSelectsAll`, copying automatic URL bar selection to clipboard, etc.
This also applies to Firefox ESR.

## Where does this script work?

The script works for _me_. 😉
And _I’m_ running Firefox Nightly on Arch Linux.
This is the software setup that I’ve _tested_ — it may work for other setups, too, and this script is likely to work with later versions as well:

<!--
Versions:
pacman -Qi linux gnome-desktop unzip zip
-->

* Firefox Nightly 91 (2020-07-01) through 146 (2025-10-22) (64-Bit)
* Firefox ESR 78 through 102 (64-bit)
* Arch Linux ([`core/linux`][linux] `5.8.1.arch1-1` through `6.17.4.arch2-1`)
* Gnome Desktop ([`extra/gnome-desktop`][gnome-desktop] `1:3.36.5-1` through `1:44.4-1`)
* Bash 4.x+
* Info-ZIP UnZip ([`extra/unzip`][unzip] `6.0-14` through `6.0-23`)
* Info-ZIP Zip ([`extra/zip`][zip] `3.0-9` through `3.0-11`)

_Note: the versions will only be updated for substantial changes to the script._

## How to run the script?

The script applies changes to a set of Firefox install paths; it needs to be executed after an update of the Firefox install paths.
It should not be executed a second time before another Firefox update.

The script automatically modifies the `omni.ja` files and the `browser/omni.ja` files, and clears the browsers’ startup caches and creates `.purgecaches` files, in order to assure that the changes are properly applied when starting Firefox.

This step-by-step guide describes default script execution, i.e. without any presets or options passed. You can use the [web app] to choose custom presets for the script or pass [options](#options-in-detail) listed below.

Also see [my Super User answer][super-user] for detailed steps.

### Before using the script for the _first_ time

1. Download the script from the [original source][sh].
2. Set the script as a runnable file.

### Before running the script

3. Update all Firefox browsers you want to fix and start each Firefox browser so they install all the updates properly.
4. Close all Firefox browsers you want to fix.

### Running the script

5. Execute the script.
   
   * Interactively: Either click it in your file manager, then click the <kbd>Run in terminal</kbd> button, or run it directly as e.g. `bash ./fixfx.sh`.
   * Non-interactively: Click it in your file manager, then click the <kbd>Run</kbd> button (i.e. running in background; no terminal shown).
   
   Interactive execution is recommended.
6. The script should find your Firefox install path(s) automatically.
   If multiple viable paths are found, you can select the ones you want to fix.
   If no paths are found, you can either
   
   * call the script with the [`--firefox` option](#options-in-detail), specifying the Firefox install paths, or
   * use the [web app] to download a version of the script with the paths specified in the presets.
   
   The correct paths contain an `omni.ja` file, as well as a `browser` directory with another `omni.ja` file in it.
7. The script checks if you have write access to all relevant directories: the Firefox install paths, the backup path, and `/tmp`, where the unzipping happens.
   If not, you’ll be asked to enter your root password.
   You can also run the script with `sudo` instead.
8. All specified Firefox paths are processed:
   1. A backup of the internal application resources (`omni.ja` and `browser/omni.ja`) of your Firefox installation is created (in `/tmp`, by default).
   2. After a few moments, you should be able to launch the processed Firefox browser normally.
      If everything went well, you can now test your browser with an improved user experience!
      Press <kbd>Enter</kbd> to exit.
   3. However, if the Firefox browser won’t run properly, close Firefox, and restore the backup by typing <kbd>r</kbd> and <kbd>Enter</kbd>.
      The backup will be restored.
      Start Firefox again to go back to normal.
   4. Repeat for the next Firefox path; at the end, the script will exit.

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
firefox_dir=$(whereis -b firefox | cut -d ' ' -f 2)          # Or put the correct path here, like `firefox_dir=/usr/lib/firefox`.
                                                             # `cut -d ' ' -f 2` just takes the first path found, which might not be the right one.
cp -p /tmp/omni-n.ja~ "$firefox_dir/omni.ja"                 # Replace `n` by the incremental number of the backup file name.
cp -p /tmp/browser_omni-n.ja~ "$firefox_dir/browser/omni.ja" # Replace `n` by the incremental number of the backup file name.
touch "$firefox_dir/browser/.purgecaches"                    # This is necessary only here. A "$firefox_dir/.purgecaches" is ignored.
```

## Using the web app

The [web app] lets you choose all the options and tweaks that you want and put them into a customized shell script as presets.

Once you’ve downloaded the customized script, set it as a runnable file, make sure Firefox is up-to-date and closed, and then run the script ([steps 2, 3, and 4](#how-to-run-the-script)).
The script should then run exactly as specified.
You can make sure if the presets are set correctly: they’re in the `settings` array between `# Begin presets.` and `# End presets.`.

You can theoretically still pass command line options to the script; these will get additionally applied.
For example, if you specified a `firefoxDirs|0` in the web app, passing another `-f` directory will add it as `firefoxDirs|1`.
Opt-in options such as `-q`, `-a`, or `-y` cannot be disabled once they’ve been enabled.
A `-b` or `-o` option is overridden by a later instance of the same option.

### Running the web app

If you fork this repo, the web app can be served using a simple HTTP server, e.g. [`http-server`](https://www.npmjs.com/package/http-server) from NPM.

## Options in detail

As usual, short options can be combined, e.g. `-qyab '/tmp'` which expands into `-q -y -a -b '/tmp'`.
A `--` marks the end of options, meaning every option after that will be ignored.
There are no positional arguments for this script, so in fact, after `--`, _everything_ is ignored.

* `-f DIR`, `--firefox DIR`

  Adds `DIR` to the collection of Firefox install paths that are to be fixed.
  Can be used multiple times: `-f DIR1 -f DIR2`, etc.
  
  Note that `DIR` must include an `omni.ja` file and a `browser/omni.ja` file.
  If it doesn’t, the path is ignored.
  
  You can use this together with `-a` to add all automatically found paths to the collection.

* `-a`, `--add-all-found`

  Automatically find all Firefox install paths and add them to the collection of Firefox install paths that are to be fixed.
  
  If neither `-f` nor `-y` are passed, the script acts as if the option is enabled by default, with one exception:
  the script will interactively prompt for a choice of Firefox paths if and only if
  * more than one path is found, and
  * an interactive prompt hasn’t already occured, and
  * the script is executed interactively, and
  * `-q` is not passed, and
  * `-a` is not passed, and
  * `-y` is not passed, and
  * `-f` is not passed.
  
  In other words, the script attempts to fix all Firefox paths by default, but since this isn’t requested explicitly, the script will ask, if possible.
  
* `-y`, `--fix-only-youngest`

  Pick only the Firefox install path from the collection with the most recent modification / install date, to be fixed.

* `-o FIX_OPTION`, `--option FIX_OPTION`

  Choose which functionality you want to change in the internal files.
  Can be used multiple times: `-o FIX_OPTION1 -o FIX_OPTION2`, etc.
  
  `FIX_OPTION` can have a few different forms:
  * To turn the option `yourOptionHere` _off_, use `yourOptionHere=` (e.g. `--option preventClickSelectsAll=` or `-o preventClickSelectsAll=`).
    This sets the option entry’s value to an empty string, which acts as a false value in Bash.
  * To turn the option `yourOptionHere` _on_, just type `yourOptionHere` by itself, or with any other substring after `=` (e.g. `-o preventClickSelectsAll` or `-o preventClickSelectsAll=true`).
  * To supply a custom value, use `yourOptionHere=yourValueHere`.
  
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
  Note that these tests aren’t perfect and that they can break using some file descriptor redirection, but it should cover most basic cases of executing this script.

* `-h`, `-?`, `--help`, `--?`

  If this option is present, the help information is printed, and the script exits.
  The help text contains contextual information such as the path name of the script source, the default options, etc.

### Interaction between `-a`, `-f`, `-q`, and `-y`

Based on the options passed to the script, the script will first collect certain Firefox paths (e.g. the specified ones from `-f`, or the automatically found ones), then filter them (e.g. the most recent modification date using `-y`, or all of them).
The script will only process the filtered set of Firefox paths.

| `-y` passed | `-a` passed | `-f` passed | Collection | Filter (resulting set) |
|:-----------:|:-----------:|:-----------:|:----------:|:----------------------:|
| ❌ | ❌ | ❌ | ➕ Automatically found | If interactively executed _and_ `-q` not passed _and_ more than one path found, prompt user to choose which paths to process. Otherwise, process all. |
| ❌ | ❌ | ✔️ | ➕ Specified | All |
| ❌ | ✔️ | ❌ | ➕ Automatically found | All |
| ❌ | ✔️ | ✔️ | ➕ Automatically found<br/>➕ Specified | All |
| ✔️ | ❌ or ✔️ | ❌ | ➕ Automatically found | Only youngest |
| ✔️ | ❌ | ✔️ | ➕ Specified | Only youngest |
| ✔️ | ✔️ | ✔️ | ➕ Automatically found<br/>➕ Specified | Only youngest |

### Available options

| Option flag                                 | Default | Description |
|---------------------------------------------|:-------:|-------------|
| `--option autoCompleteCopiesToClipboard`    |   Off   | This option requires `autoSelectCopiesToClipboard` to be set and is ignored without it. This option additionally enables copying selection in the URL bar triggered by typing a URL which is known by the browser (e.g. typing `gi` may autocomplete `github.com`, and the part `thub.com` is selected; the option enables automatically copying this selection to the clipboard).  |
| `--option autoSelectCopiesToClipboard`      |   Off   | <p>Certain actions trigger an automatic selection of text in the URL bar or the search bar which aren’t considered user-initiated and as such are not added to the selection clipboard (e.g. selected text which can be inserted with middle-click on Linux) — see <a href="https://github.com/SebastianSimon/firefox-omni-tweaks/wiki/Selection-clipboard-behavior">the wiki entry</a>.</p><p>This option enables clipboard selection for most cases: <kbd>Ctrl</kbd>+<kbd>L</kbd> or <kbd>F6</kbd> for URL bar selection; <kbd>Ctrl</kbd>+<kbd>K</kbd> for search bar selection; <kbd>Esc</kbd> to restore the original URL; <kbd>Tab</kbd> to focus either URL bar or search bar; or single-click or double-click selecting the entire text — if enabled.</p><p>However, additional options must be passed if selection triggered by a tab switch should also be copied (<code>tabSwitchCopiesToClipboard</code>), and if selection triggered by URL auto-complete should be copied (<code>autoCompleteCopiesToClipboard</code>).</p> |
| `--option clearSearchBarOnSubmit`           |   Off   | Submitting a search from the separate search bar clears it. There’s discussion about this feature on <a href="https://superuser.com/q/319449/751213" title="Is it possible to automatically empty the Firefox search bar?">Super User</a> and on <a href="https://bugzilla.mozilla.org/show_bug.cgi?id=253331" title="Search bar’s text should be cleared after a search is performed">Bugzilla</a>. |
| `--option doubleClickSelectsAll`            |   Off   | Double-clicking the URL bar or the search bar selects the entire input field. |
| `--option preventClickSelectsAll`           |   On    | Clicking the URL bar or the search bar no longer selects the entire input field. |
| `--option secondsSeekedByKeyboard=`_number_ |         | Pressing <kbd>←</kbd> or <kbd>→</kbd> in the built-in video player (including Picture-in-Picture mode) seeks by _number_ seconds. [Bugzilla Bug 1668692](https://bugzilla.mozilla.org/show_bug.cgi?id=1668692) already changed this from 15 seconds to 5 seconds, but still didn’t offer an easily accessible option to change this duration. |
| `--option tabSwitchCopiesToClipboard`       |   Off   | This option requires `autoSelectCopiesToClipboard` to be set and is ignored without it. This option additionally enables copying selection in URL bar triggered by switching to a tab with a focused URL bar (with either clicking or with <kbd>Ctrl</kbd>+(<kbd>Shift</kbd>)+<kbd>Tab</kbd>, <kbd>Ctrl</kbd>+<kbd>Page Up</kbd>, <kbd>Ctrl</kbd>+<kbd>Page Down</kbd>, <kbd>Alt</kbd>+<kbd>1</kbd>..<kbd>9</kbd>, and possibly other ways). |

### Examples

We’ll assume that the script is callable via `./fixfx.sh`.
The exact path and file name depends on where you placed the file.

* The following command fixes a specific Firefox installation located under `/usr/lib/firefox-de_DE` and creates an incremental backup of the original `omni.ja` files in `/tmp`.
  The specified directory must contain an `omni.ja` and a `browser/omni.ja`.

  ```sh
  ./fixfx.sh --firefox /usr/lib/firefox-de_DE
  ```

* This command fixes a set of automatically determined Firefox installations, while creating a backup of `omni.ja` and `browser/omni.ja` in the specified directory.
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
* `2` for incorrect script usage: e.g. `--backup`, `--firefox`, or `--option` used without values, the specified Backup directory isn’t an existing directory, no valid Firefox path found, etc.
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


  [web app]: https://sebastiansimon.github.io/firefox-omni-tweaks
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
