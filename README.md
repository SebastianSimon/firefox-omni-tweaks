# Firefox Selection Fix – Click will no longer select all in your URL bar

_**Note:** Currently, the script and this repository are undergoing changes in scope. The newly introduced [options](#available-options) are the first step to generalize this script for various `omni.ja` tweaks, not just the `clickSelectsAll` behavior. Stay tuned._

---

A script that disables the broken `clickSelectsAll` behavior of Firefox.

See [this answer on Super User][super-user] for full context and an explanation of the script.

## What is this script for?

Various browsers have started adopting a particular behavior when clicking the address bar: the entire URL is selected.
This goes against good UX practices.
In Firefox, there used to be the preferences `browser.urlbar.clickSelectsAll`, `browser.urlbar.update1`, and `browser.urlbar.update2` to control this behavior and other updates, but the latter two were always expected to be temporary.

Around March 2020, the [`browser.urlbar.clickSelectsAll` preference has been removed][regression-bug].
Since then, this bug has been [under discussion][bug], where a patch has been suggested — this would involve recompiling Firefox from scratch.
As the _“`clickSelectsAll` doesn’t work”_ duplicates accumulate on Bugzilla, one of these has received a [comment by Stephen McCarthy][bugzilla-workaround] which describes a workaround that involves editing internal Firefox files.
This workaround looks like the simplest approach, but the approach doesn’t work as-is.

This repo provides a script that attempts to give us users the `browser.urlbar.clickSelectsAll = false` experience back.

## Where does this script work?

The script works for _me_. 😉
And _I’m_ running Firefox Nightly on Arch Linux.
This is the software setup that I’ve _tested_ — it may work for other setups, too, and this script is likely to work with later versions as well:

<!--
Versions:
pacman -Qi linux gnome-desktop unzip zip
-->

* Firefox Nightly 81.0a1 (2020-08-20) through 91.0a1 (2021-06-19) (64-bit)
<!-- * Firefox ESR 78 (64-bit) (assumed to work, not actually tested yet) -->
* Arch Linux ([`core/linux`][linux] `5.8.1.arch1-1` through `5.12.9.arch1-1`)
* Gnome Desktop ([`extra/gnome-desktop`][gnome-desktop] `1:3.36.5-1` through `1:40.1-2`)
* Bash 4.x+
* Info-ZIP UnZip ([`extra/unzip`][unzip] `6.0-14`)
* Info-ZIP Zip [`extra/zip`][zip] `3.0-9`

_Note: the versions will only be updated for substantial changes to the script._

## How to run the script?

The script applies changes to a specific Firefox install path; it needs to be executed after each update of that Firefox install path.
It should not be executed a second time before another Firefox update.

The script automatically modifies the `browser/omni.ja` file, and clears the browser’s startup cache and creates a `.purgecaches` file, in order to assure that the changes are properly applied when starting Firefox.

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
   
   * Interactively: Either click it in your file manager, then click the “Run in terminal” button, or run it directly as e.g. `bash ./fixfx-selection.sh`.
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
8. A backup of the internal application resources (`browser/omni.ja`) of your Firefox installation is created (in `/tmp`, by default).
9. After a few moments, you should be able to launch Firefox normally.
   If everything went well, you should now be able to launch a fixed Firefox with an improved URL bar selection behavior (and search bar, too)!
   Press <kbd>Enter</kbd> to exit.
10. However, if Firefox won’t run properly, close Firefox, and restore the backup by typing <kbd>r</kbd> and <kbd>Enter</kbd>.
    The backup will be restored and the script will exit.
    Start Firefox again to go back to normal.

Let me know if something went wrong, by creating a new issue.
Provide details about terminal output, your system setup, and your software versions.

Since this script partially relies on Firefox making sure to use the newly changed `browser/omni.ja`, as opposed to a cached `omni.ja` file, additional care must be taken to make issues reproducible.
See the [wiki about the startup cache][wiki-cache] to gain insight into the cache clearing mechanism.

### Restoring the backup

The script offers an opportunity to test Firefox and restore the backup in case something went wrong.
It also tells you which file paths are being used and tells you the command lines for restoring the backup, if not already applied.

If you need to restore the backup later on, you can type commands into the terminal which are based on the following snippet.
Check if you need to run this as root, and _double-check_ the file paths.

```sh
firefox_dir=$(whereis -b firefox | cut -d ' ' -f 2)  # Or put the correct path here, like the `Fallback path` line in the script.
                                                     # `cut -d ' ' -f 2` just takes the first path found, which may not be the right one.
cp -p /tmp/omni-n.ja~ "$firefox_dir/browser/omni.ja" # Replace `n` by the incremental number of the backup file name.
touch "$firefox_dir/browser/.purgecaches"
```

## Options in detail

As usual, short options can be combined, e.g. `-qb '/tmp'` which expands into `-q -b '/tmp'`.
A `--` marks the end of options, meaning every option after that will be ignored.
There are no positional arguments for this script, so in fact, after `--`, _everything_ is ignored.

* `-f PATH`, `--firefox PATH`

  Picks `PATH` as the Firefox install path that is to be fixed.
  
  Note that `PATH` must include a `browser/omni.ja` file.
  If this validation fails, the script terminates.
  
  Omit this option to let the script find all `firefox` or `firefox-esr` paths on your system, validate them, and pick the one directory that is found.
  If more than one viable directory is found, the script will ask for selection of a specific directory (unless `-q` or `--quiet` is passed).

* `-o FIX_OPTION...`, `--option FIX_OPTION...`, `--options FIX_OPTION...`

  Choose which functionality you want to change in the `omni.ja`.
  `FIX_OPTION` can be one or more options; this flag can be used multiple times.
  
  To turn the option `yourOptionHere` _off_, use `yourOptionHere=false` (e.g. `--option preventClickSelectsAll=false` or `-o preventClickSelectsAll=false`).
  
  To turn the option `yourOptionHere` _on_, just type `yourOptionHere` by itself, or with any other substring after `=` (e.g. `-o preventClickSelectsAll` or `-o preventClickSelectsAll=true`).
  Note that an option name entry that doesn’t exactly end with `=false` is treated as `=true`.
  
  To supply multiple option settings, either use the flag multiple times, or type the option names in a space-separated list (e.g. `-o optionA=false -o optionB` or `-o optionA=false optionB`).
  
  See the [available options](#available-options) below.
  Unrecognized options are ignored.

* `-b PATH`, `--backup PATH`

  Stores backup of internal Firefox file `browser/omni.ja` in `PATH`.
  
  If `PATH` points to a directory, an incremental file name like `omni-0.ja~`, `omni-1.ja~`, etc. is used within that directory.
  
  If `PATH` points to an existing file, the file is overwritten with the backup.
  
  If the path name of `PATH` (without the file name) points to a directory, but the file name doesn’t point to an existing file, the backup is stored with that file name.
  
  Omitting this option defaults to `/tmp` with incremental backups.

* `-q`, `--quiet`

  Only errors (specifically, anything echo’d to `STDERR`) will be logged.
  Normal (`STDOUT`) output will be suppressed.
  This will also suppress asking for confirmation.
  
  By default, output will be emitted, but if the script was not executed in an interactive terminal, all interactive selections or confirmation questions are suppressed, regardless of whether the `--quiet` option was passed or not.
  If confirmation questions are suppressed and the script finds more than one viable Firefox install path, it will automatically pick the most recently updated one.
  Note that these tests aren’t perfect and that they can break using some file descriptor redirection, but it should cover most basic cases of executing this script.

* `-h`, `-?`, `--help`, `--?`

  If this option is present, the help information is printed, and the script exits.

### Available options

| Option flag | Default | Description |
|-------------|:-------:|-------------|
| `--option preventClickSelectsAll` | On | Clicking the URL bar or the search bar no longer selects the entire input field. |

### Examples

We’ll assume that the script is callable via `./fixfx-selection.sh`.
The exact path and file name depends on where you placed the file.

* The following command fixes a specific Firefox installation located under `/usr/lib/firefox-de_DE` and creates an incremental backup of the original `omni.ja` in `/tmp`.
  The specified directory must contain a `browser/omni.ja`.

  ```sh
  ./fixfx-selection.sh --firefox /usr/lib/firefox-de_DE
  ```

* This command fixes an automatically determined Firefox installation, while creating a backup of `browser/omni.ja` in the specified directory.
  The file names are incremental, e.g. `omni-0.ja~`, `omni-1.ja~`, etc.

  ```sh
  ./fixfx-selection.sh -b /home/user/backups/my_backup_directory
  ```

* This command fixes an automatically determined Firefox installation, while creating a backup of `browser/omni.ja` at the specified file name (if its containing directory exists).
  The file is overwritten, if it exists.

  ```sh
  ./fixfx-selection.sh -b /home/user/backups/my_omni_backup.ja~
  ```

## Exit status

The script distinguishes between four different status codes when exiting.
Error codes (i.e. status codes greater than 0) are usually accompanied by an error message printed to `STDERR`.

* `0` for success: everything went as expected, the script terminated successfully.
* `1` for general failure due to utilities used in the script: e.g. some file was not found, some directory could not be created, directory navigation failed, unzipping or zipping the `omni.ja` failed, read or write permissions could not be granted, etc.
* `2` for incorrect script usage: e.g. `--backup` or `--firefox` used without values, the specified Backup directory doesn’t point to a regular file or a target within an existing directory, the specified Firefox path is not a valid Firefox path, etc.
* `130` if the script process was terminated (e.g. via <kbd>Ctrl</kbd>+<kbd>C</kbd>) or killed.


  [super-user]: https://superuser.com/a/1559926/751213
  [regression-bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=333714
  [bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=1621570
  [bugzilla-workaround]: https://bugzilla.mozilla.org/show_bug.cgi?id=1643973#c6
  [sh]: https://raw.githubusercontent.com/SebastianSimon/firefox-selection-fix/master/fixfx-selection.sh
  [linux]: https://www.archlinux.org/packages/core/x86_64/linux/
  [gnome-desktop]: https://www.archlinux.org/packages/extra/x86_64/gnome-desktop/
  [unzip]: https://www.archlinux.org/packages/extra/x86_64/unzip/
  [zip]: https://www.archlinux.org/packages/extra/x86_64/zip/
  [wiki-cache]: https://github.com/SebastianSimon/firefox-selection-fix/wiki/Careful-considerations-concerning-clearing-cache
