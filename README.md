# TrollStore

TrollStore is a permasigned jailed app that can permanently install any IPA you open in it.

It works because of the CoreTrust bug that **_ONLY_** affects iOS 14.0 - 15.4.1 (15.5b4).

**NOTE: TrollStore will _NEVER_ work on anything higher than iOS 15.5 beta 4 (No not on iOS 15.5, not on iOS 15.6 and certainly not on iOS 16.x), please stop asking!**

# Installing TrollStore

1. On your iOS device (14.0 - 15.5b4), click [this link](https://api.jailbreaks.app/troll).

2. An alert should appear, click "Install".

3. When the installation is finished, you will find a "GTA Car Tracker" application on your device.

4. If this app has not appeared, that's a stock iOS bug, reboot your device and it will appear.

5. Launch the app, tap "Install TrollStore".

6. Wait a few seconds, your device should respring and TrollStore will be installed.

7. You can now delete the "GTA Car Tracker" app, it is no longer needed.

8. Open TrollStore and press "Install ldid" in the Settings tab, then read the information under "Persistence", and install the Persistence Helper into a system app if want persistence.

9. Done, you can now share IPA files with TrollStore and they will be permanently installed on your device.

# Updating TrollStore

When a new TrollStore update is available, a button to install it will appear at the top in the TrollStore settings. When tapping the button, TrollStore will automatically download the update, install it and respring.

Alternatively (if anything goes wrong), you can download the TrollStore.tar file under Releases and open it in TrollStore, TrollStore will install the update and respring.

# Uninstalling an app

Apps installed from TrollStore can only be uninstalled from TrollStore itself, tap an app or swipe it to the right in the 'Apps' tab to delete it.

# Persistence Helper

The CoreTrust bug used in TrollStore is only enough to install "System" apps, this is because FrontBoard has an additional security check (it calls libmis) every time before a user app is launched. Unfortunately it is not possible to install new "System" apps that stay through an icon cache reload. Therefore, when iOS reloads the icon cache, all TrollStore installed apps including TrollStore itself will revert back to "User" state and will no longer launch.

The only way to work around this is to install a persistence helper into a system app, this helper can then be used to reregister TrollStore and its installed apps as "System" so that they become launchable again, an option for this is available in TrollStore settings.

On jailbroken iOS 14 when TrollHelper is used for installation, it is located in /Applications and will persist as a "System" app through icon cache reloads, therefore TrollHelper is used as the persistence helper on iOS 14.

# Features

The binaries inside an IPA can have arbitary entitlements, fakesign them with ldid and the entitlements you want (`ldid -S<path/to/entitlements.plist> <path/to/binary>`) and TrollStore will preverse the entitlements when resigning them with the fake root certificate on installation. This gives you a lot of possibilities, some of which are explained below.

## Banned entitlements

iOS 15 on A12+ has banned the following three entitlements related to running unsigned code, these are impossible to get without a PPL bypass, apps signed with them will crash on launch.

`com.apple.private.cs.debugger`

`dynamic-codesigning`

`com.apple.private.skip-library-validation`

## Unsandboxing

Your app can run unsandboxed using one of the following entitlements:

```
<key>com.apple.private.security.container-required</key>
<false/>
```

```
<key>com.apple.private.security.no-container</key>
<true/>
```

```
<key>com.apple.private.security.no-sandbox</key>
<true/>
```

The third one is recommended if you still want a sandbox container for your application.

You might also need the platform-application entitlement in order for these to work propery:

```
<key>platform-application</key>
<true/>
```

Please note that the platform-application entitlement causes side effects such as some parts of the sandbox becoming tighter, so you may need additional private entitlements to circumvent that. (For example afterwards you need an exception entitlement for every single IOKit user client class you want to access).

## Root Helpers

When your app is not sandboxed, you can spawn other binaries using posix_spawn, you can also spawn binaries as root with the following entitlement:

```
<key>com.apple.private.persona-mgmt</key>
<true/>
```

Because a root binary needs special permissions, you need to specifiy all your root binaries in the Info.plist of your application like so:

```
<key>TSRootBinaries</key>
<array>
    <string>roothelper1</string>
    <string>some/nested/roothelper</string>
</array>
```

Note: The paths in the TSRootBinaries array are relative to the location of the Info.plist, you can also include this key in other bundles such as app plugins.

Afterwards you can use the [spawnRoot function in TSUtil.m](./Store/TSUtil.m#L39) to spawn the binary as root.

## Things that are not possible using TrollStore:

- Getting proper platformization / `CS_PLATFORMIZED`
- Spawning a launch daemon (Would need `CS_PLATFORMIZED`)
- Injecting a tweak into a system process (Would need `CS_PLATFORMIZED`, a userland PAC bypass and a PMAP trust level bypass)

# Credits and Further Reading

[@LinusHenze](https://twitter.com/LinusHenze/) - Found the CoreTrust bug that allows TrollStore to work.

[Fugu15 Presentation](https://youtu.be/NIyKNjNNB5Q?t=3046)

[Write-Up on the CoreTrust bug with more information](https://worthdoingbadly.com/coretrust/).
