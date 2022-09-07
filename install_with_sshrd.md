# Install TrollStore with a SSH Ramdisk (Linux and macOS only)

1. download this tar and extract it https://github.com/opa334/TrollStore/releases/latest/download/TrollStore.tar

2. run `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`

3. run `./sshrd.sh <latestipswlinkhere>`

4. run `./sshrd.sh boot` the device should start verbosing and say OK in ascii

5. in a new terminal window, run `iproxy 2222 22`

6. In the previous window, run `ssh -p2222 root@localhost`, the pass is alpine

7. Now, in the same window, run `mount_filesystems`, if a error occurs please make a issue in the SSHRD_Script repo

8. Run `cd /mnt2/containers/Bundle/Application`

9. For the app you would like to replace, run `grep -r "<appname>" .`
    - you can put something like Tips, must be a deletable system app

10. look for a filepath that looks like ./<udid>/<appname>.app

11. run `cd <udid>/<appname>.app`

12. run `mv <appname>appname <appname>_TROLLSTORE_BACKUP`

13. Now, in another terminal window, cd into the folder of the tar you extracted earlier

14. Run `scp -P222 PersistenceHelper root@localhost:/mnt2/containers/Bundle/Application/<udid>/<appname>.app/<appname>`

15. Run `scp -P222 trollstorehelper root@localhost:/mnt2/containers/Bundle/Application/<udid>/<appname>.app/trollstorehelper`

16. In the window you sshed into the phone in, run `chown 33 <appname> & chmod 755 <appname> trollstorehelper`, `chown 0 trollstorehelper`, and run `reboot`, your phone will reboot into iOS

17. Open up the app you replaced, it should show some buttons like install trollstore, click install trollstore

18. TrollStore is installed!
