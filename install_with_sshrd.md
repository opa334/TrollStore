# Install TrollStore with a SSH Ramdisk (Linux and macOS only)

1. download this tar and extract it https://github.com/opa334/TrollStore/downloads/latest/TrollStore.tar

2. run `git clone https://github.com/verygenericname/SSHRD_Script --recursive && cd SSHRD_Script`

3. run `./sshrd.sh <latestipswlinkhere>`

4. run `./sshrd.sh boot` the device should start verbosing and say OK in ascii

5. in a new terminal window, run `iproxy 2222 22`

6. In the previous window, run `ssh -p2222 root@localhost`, the pass is alpine

7. Now, in the same window, run `mount_filesystems`, if a error occurs please make a issue in the SSHRD_Script repo

8. Run `cd /mnt2/containers/Bundle/Application`

9. For the app you would like to replace, run `grep -r "appname" .`

10. Depending on the app you chose, doesn't have to be tips, a look for a filepath that looks like <udid>/appname.app

11. run `cd <udid>/appname.app
