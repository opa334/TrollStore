# Installation through TrollInstaller 2

**Supported devices:** A12-A15, 14.0 - 15.4.1 (15.5b4)

## Compiling pwned IPA (currently requires a Mac) (Needs THEOS and 14.5 sdk installed)

1. Get a stock "Apple Developer" IPA (this app: https://apps.apple.com/de/app/apple-developer/id640199958 (sorry german link but you get the idea)), you can do this using Apple Configurator (install it twice to your device and when it gives you the already exists error, copy the IPA from `~/Library/Group\ Containers/<some_uuid>.group.com.apple.configurator/Library/Caches/Assets/TemporaryItems/MobileApps` to somewhere else and then cancel the installation).

2. Put it into _compile/target/Developer.ipa

3. Grab pwnify_compiled from Fugu14 repo (https://github.com/LinusHenze/Fugu14/blob/master/tools/pwnify_compiled), sign it using codesign (`codesign -s - <path/to/pwnify_compiled>`) and put it at _compile/pwnify_compiled

4. Make sure you have Procursus ldid installed and added to your path! (https://github.com/ProcursusTeam/ldid)

5. cd into _compile and run `./build_trollinstaller2.sh` (`chmod +x ./build_trollinstaller2.sh` if you get a permission error)

6. Wait a bit, when done, there will be a `DeveloperInstaller.ipa` in _compile/out

# Using compiled IPA (does not neccessarily require a Mac if you obtained the IPA from non orthodox ways)

7. You can install that to a device using e.g. ideviceinstaller (other methods may also work, but make sure you don't use a signing cert, you can also use an enterprise plist or something to install it via Safari as shown in Fugu15 demo, something like iFunBox may also work)

8. After installation, you can use the "Developer" app on your device to install TrollStore
