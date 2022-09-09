# Installation through an SSH Ramdisk (Linux and macOS only)

**Supported devices:** A8 - A11, iOS 14.0 - 15.5b4

1. Run `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`

2. Run `./sshrd.sh <latestipswlinkhere>`

3. Run `./sshrd.sh boot` the device should start verbosing and say OK in ascii

4. In a new terminal window, run `iproxy 2222 22`

5. In the previous window, run `ssh -p2222 root@localhost`, the pass is alpine

6. Now, in the same window, run `mount_filesystems`, if a error occurs please make a issue in the SSHRD_Script repo

7. Run `trollstoreinstaller <uninstallablesystemapphere>` (Tips is the best choice), Then run `reboot`, your phone will reboot into iOS

8. Open up the app you replaced, it should be TrollStore Helper now

9. Press "Install TrollStore", make sure you're connected to the internet

10. Done, your device will respring and TrollStore should appear on your home screen
