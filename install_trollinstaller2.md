# Installation through TrollInstaller 2

**Supported devices:** A12 - A15, 14.0 - 15.4.1 (15.5b4)

## Compiling pwned IPA (currently requires a Mac) (Needs _the newest_ [THEOS](https://theos.dev/docs/installation-macos) and [14.5 sdk](https://github.com/theos/sdks) installed)

0. Make sure Xcode and Command Line Tools are installed.

1. Run `git clone https://github.com/opa334/TrollStore ~/TrollStore`

<<<<<<< HEAD
2. Get ANY encrypted AppStore IPA using [ipatool](https://github.com/majd/ipatool/releases/tag/v1.1.4)
- Unzip, then do `chmod +x ~/Downloads/ipatool`
- `sudo mv ~/Downloads/ipatool /usr/local/bin`
=======
2. Get a stock "[Apple Developer](https://apps.apple.com/app/apple-developer/id640199958)" IPA using [ipatool](https://github.com/majd/ipatool) **(iOS15 only, iOS14 should use an old version's app)**
- `brew tap majd/repo && brew install ipatool`
>>>>>>> 22a4389b00e184dcb8828a0532993da179ef8f0a
- `ipatool auth login` 
- (Optional if you haven't 'purchase' this free app) `ipatool purchase --country US -b developer.apple.wwdc-Release` (Change US to your app store region)
- `ipatool download -b developer.apple.wwdc-Release`

<<<<<<< HEAD
> For iOS 14 please make sure to use an app that still supports iOS 14

3. Rename the output ipa to `InstallerVictim.ipa`, and put it into ~/TrollStore/_compile/InstallerVictim.ipa
=======
> For iOS 14 please follow [this](https://github.com/flowerible/How-to-Downgrade-apps-on-AppStore-with-iTunes-and-Charles-Proxy) you will need Windows, once you get ipa switch back to Mac preceed. Or follow [this](https://github.com/NyaMisty/action-ipadown). Or using [Apple Configurator](https://apps.apple.com/app/apple-configurator/id1037126344) to connect an iOS14 device [may help](https://github.com/opa334/TrollStore/blob/19647f2e662c96db5723bb985bfbe1150ab78846/install_trollinstaller2.md).

3. Rename the output ipa to `Developer.ipa`, and put it into `~/TrollStore/_compile/target/Developer.ipa`
>>>>>>> 22a4389b00e184dcb8828a0532993da179ef8f0a

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
