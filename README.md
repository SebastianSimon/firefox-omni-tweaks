# Firefox Selection Fix – Click will no longer select all in your URL bar

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

The script works for me.
And I’m running Firefox Nightly on Arch Linux.
This is the software setup that I’ve _tested_ — it may work for other setups, too, and this script is likely to work with later versions as well:

* Arch Linux ([`core/linux`][linux] `5.6.15.arch1-1` through `5.7.4.arch1-1`)
* Firefox Nightly 79.0a1 (2020-06-11 through 2020-06-22) (64-bit)
* [`extra/unzip`][unzip] `6.0-14`
* [`extra/zip`][zip] `3.0-9`

## How to run the script?

See [my Super User answer][super-user] for detailed steps.

### Preliminaries

Before running the script:

1. [Download][sh] the script.
2. The script should find out your Firefox install path automatically. If not, edit it and put the correct path where it says `Fallback path`; the correct path contains a `browser` directory with an `omni.ja` in it.
3. Locate your Firefox desktop configuration file and add `--purgecaches` to the Firefox launch command.
4. Update Firefox and let Firefox install the updates.
5. Close Firefox.
6. Set the script as a runnable file.

### Run the script

7. Execute the script (by clicking it in the file manager, or from terminal, e.g. `bash Firefox\ Selection\ Fix.sh`).
8. If you’re running the script for the first time, a backup of the internal application resources (`browser/omni.ja`) of your Firefox installation is created (located in `/tmp`). If you run the script again, you’ll be asked if the backup should be created (and overwrite the old one); press <kbd>y</kbd> and <kbd>Enter</kbd> if you’re sure that your current Firefox installation is working properly.
9. Enter your root password, hit <kbd>Enter</kbd>.
10. After a few seconds, the script should finish and you should be able to launch Firefox normally. Don’t worry about the `unzip` error messages. If everything went well, you should now be able to launch a fixed Firefox with an improved URL bar selection behavior (and search bar, too)!

### Restoring the backup

If Firefox won’t run properly, restore the backup by typing this in your terminal (double check the file paths):

```sh
sudo cp /tmp/omni.ja~ '$(whereis firefox | cut -d ' ' -f 2)/browser/omni.ja'
```


  [super-user]: https://superuser.com/a/1559926/751213
  [regression-bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=333714
  [bug]: https://bugzilla.mozilla.org/show_bug.cgi?id=1621570
  [bugzilla-workaround]: https://bugzilla.mozilla.org/show_bug.cgi?id=1643973#c6
  [sh]: https://raw.githubusercontent.com/SebastianSimon/firefox-selection-fix/master/Firefox%20Selection%20Fix.sh
  [linux]: https://www.archlinux.org/packages/core/x86_64/linux/
  [unzip]: https://www.archlinux.org/packages/extra/x86_64/unzip/
  [zip]: https://www.archlinux.org/packages/extra/x86_64/zip/
