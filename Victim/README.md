# Victim Binary and Cert

In order to support user app installations (works on anything but iOS 14 arm64), TrollStore needs a victim binary that it attaches to any binary installed by it. By default it uses the binary of "Pastebin Mobile", because the dev of that app gave me permission to use that.

In order to compile a pwned TrollInstaller2 IPA, you need to provide a dev cert with the same team ID as your target app in this directory.

```bash
./make_cert.sh <TEAM_ID>
```

(Currently victim_gta.p12 is used by the build script, this works for GTA Car Tracker app, to use another app generate a new cert with the team ID and make sure to update the path in build script too)

((Disregard the user app stuff described above, it's not implemented yet, will be in TrollStore 2.0))