# Installation through TrollInstaller 2

**Supported devices:** A12 - A15, 14.0 - 15.4.1 (15.5b4)

## Compiling pwned IPA (currently requires a Mac) (Needs [THEOS](https://theos.dev/docs/installation-macos) and [14.5 sdk](https://github.com/theos/sdks) installed)

0. Make sure Xcode and Command Line Tools are installed.

1. Do `git clone https://github.com/opa334/TrollStore`

2. Get a stock "Apple Developer" IPA using [ipatool](https://github.com/majd/ipatool/releases/tag/v1.1.4) (iOS 15 only)
- Unzip, then do `chmod +x ~/Downloads/ipatool`
- `sudo mv ~/Downloads/ipatool /usr/local/bin`
- `ipatool auth login` 
- `ipatool download -b developer.apple.wwdc-Release`

> For iOS 14 please follow [this](https://github.com/flowerible/How-to-Downgrade-apps-on-AppStore-with-iTunes-and-Charles-Proxy) you will need Windows, once you get ipa switch back to Mac preceed.

3. Rename the output ipa to `Developer.ipa`, and put it into ~/TrollStore/_compile/target/Developer.ipa

4. Grab pwnify_compiled from Fugu14 repo (https://github.com/LinusHenze/Fugu14/blob/master/tools/pwnify_compiled), sign it using codesign (`codesign -s - <path/to/pwnify_compiled>`) and put it at ~/TrollStore/_compile/pwnify_compiled

5. Make sure you have Procursus ldid installed and added to your path! (https://github.com/ProcursusTeam/ldid)
- `brew uninstall ldid` (brew ldid is bad ldid if you have it)
- Rename the Procursus ldid for your arch to `ldid`, then do `chmod +x ~/Downloads/ldid`
- `sudo mv ~/Downloads/ldid /usr/local/bin`

> As of right now you need to add an "`out`" folder in _compile

6. cd into _compile and run `./build_trollinstaller2.sh` (`chmod +x ./build_trollinstaller2.sh` if you get a permission error)

7. Wait a bit, when done, there will be a `DeveloperInstaller.ipa` in ~/TrollStore/_compile/out

> If this fails and gives you a `devpwn.ipa`, unzip that ipa and put all the contents in it back into their original places.

## Using compiled IPA (does not neccessarily require a Mac if you obtained the IPA from non orthodox ways)

8. You can install that to a device using e.g. ideviceinstaller(do `brew install ideviceinstaller` then do `ideviceinstaller -i DeveloperInstaller.ipa`)

(Other methods may also work, but make sure you don't use a signing cert, you can also use an enterprise plist or something to install it via Safari as shown in Fugu15 demo, something like iFunBox may also work)

9. After installation, you can use the "Developer" app on your device to install TrollStore
