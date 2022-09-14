# Installation through an SSH Ramdisk (Linux and macOS only)

**Supported devices:** A8(X) - A11, iOS 14.0 - 15.5b4

Video tutorial: updated tutorial soon

1. Run `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`

2. Run `./sshrd.sh <iOS version for ramdisk> TrollStore <uninstallable system app>`
    - Make sure to **not** include the `<>`
    - The uninstallable system app should be an app you don't need to use (e.g. Tips)

3. Run `./sshrd.sh boot` the device should start verbosing and show a TrollFace in ascii, then reboot eventually

4. Open up the app you replaced, it should be TrollStore Helper now

5. Press "Install TrollStore", make sure you're connected to the internet

6. Done, your device will respring and TrollStore should appear on your home screen
