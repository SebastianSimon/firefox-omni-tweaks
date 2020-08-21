# Firefox Selection Fix – Click will no longer select all in your URL bar

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

The script works for _me_.
And _I’m_ running Firefox Nightly on Arch Linux.
This is the software setup that I’ve _tested_ — it may work for other setups, too, and this script is likely to work with later versions as well:

<!--
Versions:
pacman -Qi linux gnome-desktop unzip zip
-->

* Firefox Nightly 81.0a1 (2020-08-20) (64-bit)
* Arch Linux ([`core/linux`][linux] `5.8.1.arch1-1`)
* Gnome Desktop ([`extra/gnome-desktop`][gnome-desktop] `1:3.36.5-1`)
* Info-ZIP UnZip ([`extra/unzip`][unzip] `6.0-14`)
* Info-ZIP Zip [`extra/zip`][zip] `3.0-9`

Note: the versions will only be updated for significant changes to the script.

## How to run the script?

The script only needs to be executed after each update of Firefox.

See [my Super User answer][super-user] for detailed steps.

### Before using the script for the _first_ time

1. [Download][sh] the script.
2. Set the script as a runnable file.

### Before running the script

3. Update Firefox and start Firefox so it installs all the updates properly.
4. Close Firefox.

### Running the script

5. Execute the script in an interactive terminal.
   Either click it in your file manager, then pick the “Run in terminal” option, or run it directly as e.g. `bash ./Firefox\ Selection\ Fix.sh`.
6. The script should find your Firefox install path automatically.
   If not, edit it and put the correct path where it says `Fallback path`; the correct path contains a `browser` directory with an `omni.ja` in it.
7. The script checks if you have write access to your Firefox install path and to `/tmp`.
   If not, you’ll be asked to enter your root password.
   You can also run the script with `sudo` instead.
8. If you’re running the script the first time after boot, a temporary backup of the internal application resources (`browser/omni.ja`) of your Firefox installation is created (located in `/tmp`).
   If you run the script some time later, you’ll be asked if the backup should be created (and overwrite the old one); press <kbd>y</kbd> and <kbd>Enter</kbd> if you’re sure that your current Firefox installation is working properly.
9. After a few moments, you should be able to launch Firefox normally.
   If everything went well, you should now be able to launch a fixed Firefox with an improved URL bar selection behavior (and search bar, too)!
   Press <kbd>Enter</kbd> to exit.
10. However, if Firefox won’t run properly, close Firefox, and restore the backup by typing <kbd>r</kbd> and <kbd>Enter</kbd>.
    The backup will be restored and the script will exit.
    Start Firefox again to go back to normal.

Let me know if something went wrong, by creating a new issue.
Provide details about terminal output, your system setup, and your software versions.

The script automatically modifies the `browser/omni.ja` file and creates a `.purgecaches` file.
Always [make sure to apply the changes properly][wiki-apply]; this ensures reproducibility of any issue.

### Restoring the backup

The script offers an opportunity to test Firefox and restore the backup in case something went wrong.
If you want to restore the backup later on, type these commands into the terminal.
Check if you need to run this as root, and double-check the file paths.

```sh
firefox_dir=$(whereis firefox | cut -d ' ' -f 2)
cp -p /tmp/omni.ja~ "$firefox_dir/browser/omni.ja"
touch "$firefox_dir/browser/.purgecaches"
```


  [super-user]: https://superuser.com/a/1559926/751213
  [regression-bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=333714
  [bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=1621570
  [bugzilla-workaround]: https://bugzilla.mozilla.org/show_bug.cgi?id=1643973#c6
  [sh]: https://raw.githubusercontent.com/SebastianSimon/firefox-selection-fix/master/Firefox%20Selection%20Fix.sh
  [linux]: https://www.archlinux.org/packages/core/x86_64/linux/
  [gnome-desktop]: https://www.archlinux.org/packages/extra/x86_64/gnome-desktop/
  [unzip]: https://www.archlinux.org/packages/extra/x86_64/unzip/
  [zip]: https://www.archlinux.org/packages/extra/x86_64/zip/
  [wiki-apply]: https://github.com/SebastianSimon/firefox-selection-fix/wiki/Apply-changes-to-Firefox-properly
