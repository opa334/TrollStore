# TrollStore

TrollStore is a permasigned jailed app that can permanently install any IPA you open in it.

It works because of an AMFI/CoreTrust bug where iOS doesn't verify whether or not a root certificate used to sign a binary is legit.

## Compatibility

TrollStore works on **iOS 14.0 - 15.4.1**, on **iOS 15.5 beta 1 - iOS 15.5 beta 4** and on **iOS 15.6 beta 1 - iOS 15.6 beta 5**.

iOS 15.5 RC / full build is **NOT** supported.

Anything higher than iOS 15.6 beta 5 (including iOS 15.6 RC / full build) is **NOT** supported.

Anything lower than iOS 14.0 is **NOT** supported.

Anything not supported right now will **_NEVER_** be supported, TrollStore is a one time thing, it will not receive compatibility updates in the future, please **stop asking** about it, GitHub issues regarding version support will be **closed without an answer**.

## Installing TrollStore (No Jailbreak)

### Installation Links

[TrollHelperOTA Link 1 - Supports all devices on iOS 15 and up](https://api.jailbreaks.app/troll)

[TrollHelperOTA Link 2 - Supports all arm64e (A12 - A15) devices on iOS 14 and up](https://api.jailbreaks.app/troll64e)

Please refer to "Compatibility" above to check whether your version is compatible, if it's not, these links will not work.

This installation method unfortunately does **NOT** work on arm64 (A8 - A11) iOS 14 devices. **HOWEVER**, for these devices, you can jailbreak with checkra1n and then use the jailbroken installation guide below.

### Guide (No Jailbreak)

1. Based on what device you are using, pick one of the two links above and open it.

2. An alert should appear, tap "Install"

3. When the installation is finished, you will find a "GTA Car Tracker" application on your device.

4. If this app has not appeared, that's a stock iOS bug, reboot your device and the app will appear.

5. Launch the app, tap "Install TrollStore"

6. Wait a few seconds, your device should respring and TrollStore will be installed.

7. You can now either delete the "GTA Car Tracker" app, or register it as the persistence helper by opening it and tapping the option at the bottom. If you do this, don't delete the app. 

8. Open the TrollStore app and press "Install ldid" in the Settings tab, then read the information under "Persistence", and install the Persistence Helper into a system app if you want persistence (not needed if you registered the GTA Car Tracker app as the persistence helper in step 7).

9. Done, you can now share IPA files with TrollStore and they will be permanently installed on your device.

## Installing TrollStore (Jailbreak)

Supports jailbroken devices running 14.0 and above.

### Guide

1. Open your package manager, and make sure Havoc repo (https://havoc.app) is added under Sources, then search for "TrollStore Helper" and install it.

2. After the installation, respring and the "TrollHelper" app should have appeared on your home screen.

3. Launch the app, tap "Install TrollStore"

4. Wait a few seconds, your device should respring and TrollStore will be installed.

5. Open the TrollStore app and press "Install ldid" in the Settings tab, then read the information under "Persistence", the TrollHelper app on the home screen will be your persistence helper.

6. Done, you can now share IPA files with TrollStore and they will be permanently installed on your device.

### Unjailbreaking while retaining TrollStore

Some people might prefer to use TrollStore in an unjailbroken environment, if that applies to you, follow this guide.

1. Uninstall TrollHelper from your package manager

2. Now when you launch TrollStore, it will have an option to install the persistence helper into a System app like on iOS 15, do so.

3. Now restore rootFS through your jailbreak app, afterwards use the System app to refresh app registrations.

4. Done, your device will be jailed, but TrollStore will still work.

## Updating TrollStore

When a new TrollStore update is available, a button to install it will appear at the top in the TrollStore settings. After tapping the button, TrollStore will automatically download the update, install it, and respring.

Alternatively (if anything goes wrong), you can download the TrollStore.tar file under Releases and open it in TrollStore, TrollStore will install the update and respring.

## Uninstalling an app

Apps installed from TrollStore can only be uninstalled from TrollStore itself, tap an app or swipe it to the right in the 'Apps' tab to delete it.

## Persistence Helper

The CoreTrust bug used in TrollStore is only enough to install "System" apps, this is because FrontBoard has an additional security check (it calls libmis) every time before a user app is launched. Unfortunately it is not possible to install new "System" apps that stay through an icon cache reload. Therefore, when iOS reloads the icon cache, all TrollStore installed apps including TrollStore itself will revert back to "User" state and will no longer launch.

The only way to work around this is to install a persistence helper into a system app, this helper can then be used to reregister TrollStore and its installed apps as "System" so that they become launchable again, an option for this is available in TrollStore settings.

On jailbroken iOS 14 when TrollHelper is used for installation, it is located in /Applications and will persist as a "System" app through icon cache reloads, therefore TrollHelper is used as the persistence helper on iOS 14.

## URL Scheme

As of version 1.3, TrollStore replaces the system URL scheme "apple-magnifier" (this is done so "jailbreak" detections can't detect TrollStore like they could if TrollStore had a unique URL scheme). This URL scheme can be used to install applications right from the browser, the format goes as follows:

`apple-magnifier://install?url=<URL_to_IPA>`

On devices that don't have TrollStore (1.3+) installed, this will just open the magnifier app.

## Features

The binaries inside an IPA can have arbitrary entitlements, fakesign them with ldid and the entitlements you want (`ldid -S<path/to/entitlements.plist> <path/to/binary>`) and TrollStore will preserve the entitlements when resigning them with the fake root certificate on installation. This gives you a lot of possibilities, some of which are explained below.

### Banned entitlements

iOS 15 on A12+ has banned the following three entitlements related to running unsigned code, these are impossible to get without a PPL bypass, apps signed with them will crash on launch.

`com.apple.private.cs.debugger`

`dynamic-codesigning`

`com.apple.private.skip-library-validation`

### Unsandboxing

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

You might also need the platform-application entitlement in order for these to work properly:

```
<key>platform-application</key>
<true/>
```

Please note that the platform-application entitlement causes side effects such as some parts of the sandbox becoming tighter, so you may need additional private entitlements to circumvent that. (For example afterwards you need an exception entitlement for every single IOKit user client class you want to access).

### Root Helpers

When your app is not sandboxed, you can spawn other binaries using posix_spawn, you can also spawn binaries as root with the following entitlement:

```
<key>com.apple.private.persona-mgmt</key>
<true/>
```

Because a root binary needs special permissions, you need to specify all your root binaries in the Info.plist of your application like so:

```
<key>TSRootBinaries</key>
<array>
    <string>roothelper1</string>
    <string>some/nested/roothelper</string>
</array>
```

Note: The paths in the TSRootBinaries array are relative to the location of the Info.plist, you can also include this key in other bundles such as app plugins.

Afterwards you can use the [spawnRoot function in TSUtil.m](./Shared/TSUtil.m#L74) to spawn the binary as root.

### Things that are not possible using TrollStore

- Getting proper platformization / `CS_PLATFORMIZED`
- Spawning a launch daemon (Would need `CS_PLATFORMIZED`)
- Injecting a tweak into a system process (Would need `CS_PLATFORMIZED`, a userland PAC bypass and a PMAP trust level bypass)

## Credits and Further Reading

[@LinusHenze](https://twitter.com/LinusHenze/) - Found the CoreTrust bug that allows TrollStore to work.

[Fugu15 Presentation](https://youtu.be/NIyKNjNNB5Q?t=3046)

[Write-Up on the CoreTrust bug with more information](https://worthdoingbadly.com/coretrust/).
