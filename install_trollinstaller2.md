# Installation through TrollInstaller 2

**Supported devices:** A12 - A15, 14.0 - 15.4.1 (15.5b4)

## Compiling pwned IPA (currently requires a Mac) (Needs _the newest_ [THEOS](https://theos.dev/docs/installation-macos) and [14.5 sdk](https://github.com/theos/sdks) installed)

0. Make sure Xcode and Command Line Tools are installed.

1. Run `git clone https://github.com/opa334/TrollStore ~/TrollStore`

2. Get ANY encrypted AppStore IPA using [ipatool](https://github.com/majd/ipatool/releases/tag/v1.1.4)
- Unzip, then do `chmod +x ~/Downloads/ipatool`
- `sudo mv ~/Downloads/ipatool /usr/local/bin`
- `ipatool auth login` 
- (Optional if you haven't 'purchase' this free app) `ipatool purchase --country US -b developer.apple.wwdc-Release` (Change US to your app store region)
- `ipatool download -b developer.apple.wwdc-Release`

> For iOS 14 please make sure to use an app that still supports iOS 14

3. Rename the output ipa to `InstallerVictim.ipa`, and put it into ~/TrollStore/_compile/InstallerVictim.ipa

4. Grab pwnify_compiled from Fugu14 repo (https://github.com/LinusHenze/Fugu14/blob/master/tools/pwnify_compiled), sign it using codesign (`codesign -f -s - <path/to/pwnify_compiled>`) and put it at `~/TrollStore/_compile/pwnify_compiled`

5. Make sure you have Procursus `ldid` installed and added to your path! (https://github.com/ProcursusTeam/ldid)
- `brew uninstall ldid` (brew ldid is bad ldid if you have it)
- Rename the Procursus ldid for your arch to `ldid`, then do `chmod +x ~/Downloads/ldid`
- `sudo mv ~/Downloads/ldid /usr/local/bin`

6. cd into _compile and run `./build_trollinstaller2.sh` (`chmod +x ./build_trollinstaller2.sh` if you get a permission error)

7. Wait a bit, when done, there will be a `TrollInstaller2.ipa` in ~/TrollStore/_compile/out

## Using compiled IPA (does not neccessarily require a Mac if you obtained the IPA from non orthodox ways)

8. You can install that to a device using e.g. ideviceinstaller(do `brew install ideviceinstaller` then do `ideviceinstaller -i TrollInstaller2.ipa`)

Alternatively, you can use Sideloadly if you select "Normal Installation".

(Other methods may also work, but make sure you don't use a signing cert, you can also use an enterprise plist or something to install it via Safari as shown in Fugu15 demo, something like iFunBox may also work)

9. After installation, you can use the newly installed app on your device to install TrollStore
