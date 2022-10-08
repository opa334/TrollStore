# Installation through TrollInstaller 2

**Supported devices:** A12 - A15, 14.0 - 15.4.1 (15.5b4)

## Installing pre-compiled application (Recommended)

All of these steps should be done on your iPhone/iPad; a computer is not needed.

1. Open [this link](https://api.jailbreaks.app/troll) on your device

2. Tap "Install" on the prompt
    + The app that appears on your home screen will be called "GTA Car Tracker"; this is normal.

3. Open the app and tap "Install TrollStore"
    + This will also trigger a respring
4. Open the newly-installed TrollStore and navigate to Settings.

5. Install ldid. Then, read the information under "Persistence", and install Persistence Helper if you would like it.


## Compiling pwned IPA (Advanced) (currently requires a Mac) (Needs _the newest_ [THEOS](https://theos.dev/docs/installation-macos) and [14.5 sdk](https://github.com/theos/sdks) installed)

0. Make sure Xcode and Command Line Tools are installed.

1. Run `git clone https://github.com/opa334/TrollStore ~/TrollStore`

2. Get ANY encrypted AppStore IPA using [ipatool](https://github.com/majd/ipatool)
- In this example, the "Developer" app by Apple will be used, this app only supports iOS 15 and up, for iOS 14 support replace `developer.apple.wwdc-Release` in the following commands with the identifier of an app that still supports iOS 14
- `brew tap majd/repo && brew install ipatool`
- (Optional if you haven't 'purchase' this free app) `ipatool purchase --country US -b developer.apple.wwdc-Release` (Change US to your app store region)
- `ipatool download -b developer.apple.wwdc-Release`

3. Rename the output ipa to `InstallerVictim.ipa`, and put it into `~/TrollStore/_compile/target/InstallerVictim.ipa`

4. Make sure you have Procursus `ldid` installed and added to your path! (https://github.com/ProcursusTeam/ldid)
- `brew uninstall ldid` (brew ldid is bad ldid if you have it)
- Rename the Procursus ldid for your arch to `ldid`, then do `chmod +x ~/Downloads/ldid`
- `sudo mv ~/Downloads/ldid /usr/local/bin`

5. cd into _compile and run `./build_trollinstaller2.sh` (`chmod +x ./build_trollinstaller2.sh` if you get a permission error)

6. Wait a bit, when done, there will be a `TrollInstaller2.ipa` in ~/TrollStore/_compile/out

### Using compiled IPA (does not neccessarily require a Mac if you obtained the IPA from non orthodox ways)

7. You can install that to a device using e.g. ideviceinstaller(do `brew install ideviceinstaller` then do `ideviceinstaller -i TrollInstaller2.ipa`)

- Alternatively, you can use Sideloadly if you select "Normal Installation".

- (Other methods may also work, but make sure you don't use a signing cert, you can also use an enterprise plist or something to install it via Safari as shown in Fugu15 demo, something like iFunBox may also work)

8. After installation, you can use the newly installed app on your device to install TrollStore
