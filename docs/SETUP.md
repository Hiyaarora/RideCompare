# RideCompare — Development Environment Setup

Machine: MacBook Pro, Apple M5 (arm64), 24 GB RAM, macOS 26.5 (25F71), shell `zsh`.
Account: standard (non-admin) user on a managed Mac. Privileged software comes from **Self Service**;
everything else is installed per-user under `$HOME` with no `sudo`.

Setup date: 2026-11-13.

---

## 1. Installed tools

| Tool | Version | Source | Location |
|---|---|---|---|
| Xcode | 26.4 (17E192) | Self Service | `/Applications/Xcode.app` |
| Xcode Command Line Tools | 26.6 | Self Service | `/Library/Developer/CommandLineTools` |
| iOS Simulator runtime | iOS 26.4 (23E244) | `xcodebuild -downloadPlatform iOS` | system CoreSimulator store |
| Visual Studio Code | 1.146.0 | Self Service | `/Applications/Visual Studio Code.app` |
| Git | 2.50.1 (Apple Git-155) | Command Line Tools | `/usr/bin/git` |
| Flutter (stable) | 3.50.0 | `git clone -b stable github.com/flutter/flutter` | `~/development/flutter` |
| Dart | 3.14.0 | bundled with Flutter | `~/development/flutter/bin` |
| Android Studio | 2026.2.2 "Rabbit 2" patch 1 | developer.android.com (SHA-256 verified) | `~/Applications/Android Studio.app` |
| Java (JBR) | OpenJDK 25.0.4 | bundled with Android Studio | `…/Android Studio.app/Contents/jbr/Contents/Home` |
| Android cmdline-tools | build 15859902 | dl.google.com (SHA-256 verified) | `~/Library/Android/sdk/cmdline-tools/latest` |
| Android platform-tools (adb) | 37.0.1 | `sdkmanager` | `~/Library/Android/sdk/platform-tools` |
| Android Emulator | 37.2.13 | `sdkmanager` | `~/Library/Android/sdk/emulator` |
| Android SDK Platform | android-36 | `sdkmanager` | `~/Library/Android/sdk/platforms` |
| Android Build-Tools | 36.1.0 | `sdkmanager` | `~/Library/Android/sdk/build-tools` |
| Android system image | android-36, Google Play, arm64-v8a | `sdkmanager` | `~/Library/Android/sdk/system-images` |
| Node.js LTS ("Lithium") | v26.13.1 | nodejs.org tarball (SHASUMS256 verified) | `~/development/tools/node` |
| npm | 11.20.0 | bundled with Node | `~/development/tools/node/bin` |
| Ruby (Homebrew portable-ruby) | 3.4.5 | github.com/Homebrew/homebrew-portable-ruby (SHA-256 verified) | `~/development/tools/ruby` |
| CocoaPods | 1.17.0 | `gem install cocoapods` | `~/.gem/bin/pod` |
| MongoDB Community Server | 9.0.8 | fastdl.mongodb.org (SHA-256 verified) | `~/development/tools/mongodb` |
| mongosh | 2.14.2 | downloads.mongodb.com | `~/development/tools/mongosh` |

All downloaded binaries were also checked with `codesign -dv` and carry the expected publisher
Team IDs: Google `EQHXZ8M8AV`, MongoDB `4XWMY46275`, Node.js `HX7739G8FX`.

Downloaded archives are kept in `~/development/_downloads/` (safe to delete once you're happy).

### Why not Homebrew?
`/opt/homebrew` exists but is owned by `root` with mode `700` (created by device management), and the
account is not an administrator, so Homebrew cannot be installed or used. Every tool that would normally
come from Homebrew was installed from the vendor's official archive into `~/development/tools` instead.
If Homebrew later appears in Self Service it can coexist; just avoid installing the same tool twice.

### Why a portable Ruby?
macOS ships Ruby 2.6, and current CocoaPods dependencies require Ruby ≥ 3.3. Homebrew's official
portable-ruby build is relocatable, Apple-Silicon native and needs no admin rights.

---

## 2. Shell configuration (`~/.zshrc`)

A backup of the original file was saved as `~/.zshrc.backup-<timestamp>`.
The environment lives in one marked block, and each PATH entry is only added if it isn't already present,
so re-sourcing the file never creates duplicates:

```zsh
# >>> RideCompare dev environment >>>
export DEV_TOOLS="$HOME/development/tools"
export JAVA_HOME="$HOME/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
_add_path() { case ":$PATH:" in *":$1:"*) ;; *) export PATH="$1:$PATH" ;; esac; }
_add_path "$HOME/development/flutter/bin"
_add_path "$HOME/.pub-cache/bin"
_add_path "$DEV_TOOLS/node/bin"
_add_path "$DEV_TOOLS/mongodb/bin"
_add_path "$DEV_TOOLS/mongosh/bin"
_add_path "$JAVA_HOME/bin"
_add_path "$ANDROID_HOME/cmdline-tools/latest/bin"
_add_path "$ANDROID_HOME/platform-tools"
_add_path "$ANDROID_HOME/emulator"
_add_path "$DEV_TOOLS/ruby/bin"
_add_path "$HOME/.gem/bin"
export GEM_HOME="$HOME/.gem"
unset -f _add_path
# <<< RideCompare dev environment <<<
```

The VS Code `code` command is also on PATH, and the pre-existing `~/.local/bin` line (Claude Code)
was made duplicate-safe.

Open a new Terminal tab (or run `source ~/.zshrc`) after any change.

---

## 3. Android

```zsh
# licences (accepted 2026-11-13 with the user's permission)
sdkmanager --licenses

# packages
sdkmanager --install platform-tools emulator "platforms;android-36" "build-tools;36.1.0" \
  "system-images;android-36;google_apis_playstore;arm64-v8a"

# virtual device
avdmanager create avd -n RideCompare_Pixel \
  -k "system-images;android-36;google_apis_playstore;arm64-v8a" -d pixel_8
```

Start the emulator:

```zsh
emulator -avd RideCompare_Pixel &        # or: flutter emulators --launch RideCompare_Pixel
adb devices                              # should list emulator-5554
```

Note: `sdkmanager` now prints a deprecation notice pointing at the new `android sdk` command. Both work.

### ⚠️ Known network issue: Gradle download from Java
On this network, **Java processes cannot connect to `release-assets.githubusercontent.com`** (connection
times out), while `curl` can. Gradle distributions are served from that host, so the Gradle wrapper's
own download fails with `java.net.ConnectException: Operation timed out`. Maven Central and Google's
Maven repo are reachable from Java and are unaffected.

Workaround: pre-fetch the Gradle distribution with `curl` into the wrapper cache. The wrapper
then finds it and never downloads anything itself:

```zsh
# folder name = base-36 MD5 of the distributionUrl; for gradle-9.5.0-all it is:
DIR=~/.gradle/wrapper/dists/gradle-9.5.0-all/aca6g93cdtcf0oapcfka748qh
mkdir -p "$DIR" && cd "$DIR"
curl -fL -o gradle-9.5.0-all.zip https://services.gradle.org/distributions/gradle-9.5.0-all.zip
echo "$(curl -fsSL https://services.gradle.org/distributions/gradle-9.5.0-all.zip.sha256)  gradle-9.5.0-all.zip" | shasum -a 256 -c
```

That host is also throttled to roughly 40 KB/s on this network, so the ~220 MB file takes about an hour.
The proper fix is to ask IT to allow Java/Gradle access to `release-assets.githubusercontent.com`.

---

## 4. iOS

* Xcode installed via Self Service, and the licence was already accepted by the package.
* First-launch components were installed by opening Xcode once (`xcodebuild -checkFirstLaunchStatus` → 0).
* Developer mode is enabled (`DevToolsSecurity -status`).
* Simulator runtime: `xcodebuild -downloadPlatform iOS` (8.46 GB, no admin prompt).
* CocoaPods 1.17.0 via portable Ruby (see above).

```zsh
open -a Simulator
xcrun simctl boot "iPhone 17"
xcrun simctl list devices booted
```

---

## 5. MongoDB

Runs as a normal user process (no launchd service, no admin rights), bound to `127.0.0.1:27017` only.

* Config: `~/development/mongodb-data/mongod.conf`
* Data:   `~/development/mongodb-data/db`
* Logs:   `~/development/mongodb-data/log/mongod.log`

Helper commands (in `~/.local/bin`):

| Command | What it does |
|---|---|
| `mongo-start` | Starts `mongod` in the background and waits until it answers a ping |
| `mongo-stop` | Shuts the server down cleanly (`db.shutdownServer()`) |
| `mongo-status` | Prints the running version, or "MongoDB is not running" |
| `mongosh` | Interactive shell, connects to `mongodb://127.0.0.1:27017` |

MongoDB does **not** auto-start at login; run `mongo-start` before working on the backend.

---

## 6. Verification (2026-11-13)

| Command | Result |
|---|---|
| `flutter doctor -v` | ✅ No issues found (Flutter, Android toolchain, Xcode, Chrome, devices, network) |
| `flutter --version` | Flutter 3.50.0 stable, Dart 3.14.0 |
| `dart --version` | 3.14.0 (stable) macos_arm64 |
| `git --version` | 2.50.1 (Apple Git-155) |
| `node --version` | v26.13.1 |
| `npm --version` | 11.20.0 |
| `pod --version` | 1.17.0 |
| `java -version` | OpenJDK 25.0.4 |
| `adb version` | 1.0.41 / 37.0.1 |
| `xcodebuild -version` | Xcode 26.4, build 17E192 |
| `mongo-status` | MongoDB up, version 9.0.8 (insert/read/drop test passed) |
| `flutter devices` | `emulator-5554` (Android 16 / API 36) and `iPhone 17` (iOS 26.4) both detected |
| iOS end-to-end | ✅ Sample Flutter app built, installed and launched on iPhone 17; RideCompare integration test passes on iPhone 17 against the live backend |
| Android end-to-end | ⏳ Blocked on the Gradle download described in §3 (about 107 of 220 MB at 10 KB/s on 2026-11-13). Emulator, SDK and licences are all ready |

### Finishing the Android build once Gradle is available

The wrapper looks for `~/.gradle/wrapper/dists/gradle-9.5.0-all/aca6g93cdtcf0oapcfka748qh/gradle-9.5.0-all.zip`.
Any of these works:

* **Resume the download** (picks up where it stopped):
  ```zsh
  cd ~/.gradle/wrapper/dists/gradle-9.5.0-all/aca6g93cdtcf0oapcfka748qh
  curl -fL -C - -o gradle-9.5.0-all.zip https://services.gradle.org/distributions/gradle-9.5.0-all.zip
  echo "$(curl -fsSL https://services.gradle.org/distributions/gradle-9.5.0-all.zip.sha256)  gradle-9.5.0-all.zip" | shasum -a 256 -c
  ```
* **Download it on a different network** (home Wi-Fi, phone hotspot) in a browser from
  https://services.gradle.org/distributions/gradle-9.5.0-all.zip, then move it into the folder above,
  replacing the partial file, and run the `shasum` check.
* **Ask IT** to allow Java/Gradle access to `release-assets.githubusercontent.com`.

Then:

```zsh
cd ~/ridecompare/mobile
flutter build apk --debug
flutter emulators --launch RideCompare_Pixel
adb shell pm grant com.ridecompare.ridecompare android.permission.ACCESS_FINE_LOCATION   # after first install
adb emu geo fix 77.5946 12.9716
flutter test integration_test -d emulator-5554
```

---

## 7. Troubleshooting

* **`command not found` after setup**: open a new terminal or `source ~/.zshrc`.
* **Emulator closes right away when started from a script**: start it detached (`emulator -avd … &`) from
  a shell that stays open, or use `flutter emulators --launch RideCompare_Pixel`.
* **Gradle `ConnectException` / timeout**: see §3.
* **CocoaPods errors about Ruby version**: check that `which ruby` is `~/development/tools/ruby/bin/ruby`.
* **Need something that requires admin**: request it through Self Service or IT; nothing in this setup uses `sudo`.
