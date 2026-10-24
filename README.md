# Bai

Back up and restore other apps' data on [TrollStore](https://github.com/opa334/TrollStore) devices, pick an app, get a zip of its data, then pick that zip later and it's written back.

> **Warning:** Restoring overwrites the target app's data.

Developed on an iPhone 11 running iOS 16.6.1, requires iOS 15.0 or newer and TrollStore.

AI was used in the making of this app.

## Use

- **Backup:** tap an app, and the zip opens in the share sheet.
- **Restore:** tap **Choose Backup File**, pick a Bai zip, and make sure the app is installed first.
- **Restore points:** long-press an app and choose **Save as Restore Point…**, then on the Restore tab open **Restore Points** and tap one to roll the app back, which replaces the app's current data, so close the app first.

## Build

You need a Mac, an internet connection, and about 10 GB of free space for Xcode.

**1. Install the tools**

- Install **Xcode** from the Mac App Store, then open it once so it can finish installing its extra components.
- Install **Homebrew** from [brew.sh](https://brew.sh), it's a package manager, and the build uses it to fetch two small tools.
- Both of those tools, `xcodegen` and `ldid`, get installed automatically if you use `Build Bai.command` below, or you can install them yourself with `brew install xcodegen ldid`.

**2. Get the project**

Download this repo with **Code → Download ZIP** on GitHub, then unzip it somewhere easy to find, like your Desktop.

**3. Build it**

Pick one of these:

- **Double-click `Build Bai.command`,** a Terminal window opens and walks through 7 steps, installing missing tools, generating the Xcode project, compiling, stripping debug info, signing, and packaging. If macOS refuses to open it because it's from an unidentified developer, right-click the file, choose **Open**, then confirm, and if you get "permission denied", run `chmod +x "Build Bai.command"` in Terminal and try again.
- **Or use Terminal,** run `cd` into the project folder, then `./build_tipa.sh`, after installing the tools yourself with the `brew` command above.

The first build takes a few minutes because it downloads the one dependency, [ZIPFoundation](https://github.com/weichsel/ZIPFoundation), and when it finishes you'll have **`Bai.tipa`** in the project folder, the double-click version also shows it in Finder for you. If it fails, scroll up in the Terminal window and look for the line that says `error`.

**4. Install it on your iPhone**

- Send `Bai.tipa` to your phone, with AirDrop or by copying it into the Files app.
- Open it with **TrollStore**, either tap the file, then Share, then TrollStore, or tap the install button inside TrollStore and pick the file, then tap **Install**.

Don't build and run straight from Xcode, it won't work, because the special permissions Bai needs are added by `ldid` in the build scripts, not by Xcode.
