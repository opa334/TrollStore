# Installation through an SSH Ramdisk (Linux and macOS only)

**Supported devices:** A8 - A11, iOS 14.0 - 15.5b4

1. Download this tar and extract it https://github.com/opa334/TrollStore/releases/latest/download/TrollStore.tar

2. Run `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`

3. Run `./sshrd.sh <latestipswlinkhere>`

4. Run `./sshrd.sh boot` the device should start verbosing and say OK in ascii

5. In a new terminal window, run `iproxy 2222 22`

6. In the previous window, run `ssh -p2222 root@localhost`, the pass is alpine

7. Now, in the same window, run `mount_filesystems`, if a error occurs please make a issue in the SSHRD_Script repo

8. Run `cd /mnt2/containers/Bundle/Application`

9. For the app you would like to replace, run `grep -r "<appname>" .`
    - you can put something like Tips, must be a deletable system app

10. Look for a filepath that looks like `./<udid>/<appname>.app`

11. Run `cd <udid>/<appname>.app`

12. Run `mv <appname> <appname>_TROLLSTORE_BACKUP`

13. Now, in another terminal window, cd into the folder of the tar you extracted earlier

14. Run `scp -P2222 PersistenceHelper root@localhost:/mnt2/containers/Bundle/Application/<udid>/<appname>.app/<appname>`

15. Run `scp -P2222 trollstorehelper root@localhost:/mnt2/containers/Bundle/Application/<udid>/<appname>.app/trollstorehelper`

16. In the window you sshed into the phone in, run `chown 33 <appname> & chmod 755 <appname> trollstorehelper & chown 0 trollstorehelper`, and run `reboot`, your phone will reboot into iOS

17. Open up the app you replaced, it should be TrollStore Helper now

18. Press "Install TrollStore", make sure you're connected to internet

19. Done, your device will respring and TrollStore should appear on your home screen
