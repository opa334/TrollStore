# TrollStore

TrollStore is a permasigned jailed app that can permanently install any IPA you open in it.

It works because of an AMFI/CoreTrust bug where iOS does not verify whether or not a root certificate used to sign a binary is legit.

## Installing TrollStore

### Installation Guides

| Version / Device | arm64 (A8 - A11) | arm64e (A12 - A15, M1) |
| --- | --- | --- |
| 13.7 and below | Not Supported (CT Bug only got introduced in 14.0) | Not Supported (CT Bug only got introduced in 14.0) |
| 14.0 - 14.8.1 | [checkra1n + TrollHelper](./install_trollhelper.md) | [TrollHelperOTA (arm64e)](./install_trollhelperota_arm64e.md) |
| 15.0 - 15.4.1 | [TrollHelperOTA (iOS 15+)](./install_trollhelperota_ios15.md) | [TrollHelperOTA (iOS 15+)](./install_trollhelperota_ios15.md) |
| 15.5 beta 1 - 4 | [TrollHelperOTA (iOS 15+)](./install_trollhelperota_ios15.md) | [TrollHelperOTA (iOS 15+)](./install_trollhelperota_ios15.md) |
| 15.5 (RC) | Not Supported (CT Bug fixed) | Not Supported (CT Bug fixed) |
| 15.6 beta 1 - 5 | [SSH Ramdisk](./install_sshrd.md) | [TrollHelperOTA (arm64e)](./install_trollhelperota_arm64e.md) |
| 15.6 (RC1/2) and above | Not Supported (CT Bug fixed) | Not Supported (CT Bug fixed) |

This version table is final, TrollStore will never support anything other than the versions listed here. Do not bother asking, if you got a device on an unsupported version, it's best if you forget TrollStore even exists.

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

```xml
<key>com.apple.private.security.container-required</key>
<false/>
```

```xml
<key>com.apple.private.security.no-container</key>
<true/>
```

```xml
<key>com.apple.private.security.no-sandbox</key>
<true/>
```

The third one is recommended if you still want a sandbox container for your application.

You might also need the platform-application entitlement in order for these to work properly:

```xml
<key>platform-application</key>
<true/>
```

Please note that the platform-application entitlement causes side effects such as some parts of the sandbox becoming tighter, so you may need additional private entitlements to circumvent that. (For example afterwards you need an exception entitlement for every single IOKit user client class you want to access).

In order for an app with `com.apple.private.security.no-sandbox` and `platform-application` to be able to access it's own data container, you might need the additional entitlement:

```xml
<key>com.apple.private.security.storage.AppDataContainers</key>
<true/>
```

### Root Helpers

When your app is not sandboxed, you can spawn other binaries using posix_spawn, you can also spawn binaries as root with the following entitlement:

```xml
<key>com.apple.private.persona-mgmt</key>
<true/>
```

You can also add your own binaries into your app bundle.

Afterwards you can use the [spawnRoot function in TSUtil.m](./Shared/TSUtil.m#L74) to spawn the binary as root.

### Things that are not possible using TrollStore

- Getting proper platformization (`TF_PLATFORM` / `CS_PLATFORMIZED`)
- Spawning a launch daemon (Would need `CS_PLATFORMIZED`)
- Injecting a tweak into a system process (Would need `TF_PLATFORM`, a userland PAC bypass and a PMAP trust level bypass)

## Credits and Further Reading

[@LinusHenze](https://twitter.com/LinusHenze/) - Found the CoreTrust bug that allows TrollStore to work.

[Fugu15 Presentation](https://youtu.be/NIyKNjNNB5Q?t=3046)

[Write-Up on the CoreTrust bug with more information](https://worthdoingbadly.com/coretrust/).
