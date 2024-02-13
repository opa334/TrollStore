# TrollStore

TrollStore is a permasigned jailed app that can permanently install any IPA you open in it.

It works because of an AMFI/CoreTrust bug where iOS does not correctly verify code signatures of binaries in which there are multiple signers.

Supported versions: 14.0 beta 2 - 16.6.1, 16.7 RC (20H18), 17.0

## Installing TrollStore

For installing TrollStore, refer to the guides at [ios.cfw.guide](https://ios.cfw.guide/installing-trollstore)

16.7.x (excluding 16.7 RC) and 17.0.1+ will NEVER be supported (unless a third CoreTrust bug is discovered, which is unlikely).

## Updating TrollStore

When a new TrollStore update is available, a button to install it will appear at the top in the TrollStore settings. After tapping the button, TrollStore will automatically download the update, install it, and respring.

Alternatively (if anything goes wrong), you can download the TrollStore.tar file under Releases and open it in TrollStore, TrollStore will install the update and respring.

## Uninstalling an app

Apps installed from TrollStore can only be uninstalled from TrollStore itself, tap an app or swipe it to the left in the 'Apps' tab to delete it.

## Persistence Helper

The CoreTrust bug used in TrollStore is only enough to install "System" apps, this is because FrontBoard has an additional security check (it calls libmis) every time before a user app is launched. Unfortunately it is not possible to install new "System" apps that stay through an icon cache reload. Therefore, when iOS reloads the icon cache, all TrollStore installed apps including TrollStore itself will revert back to "User" state and will no longer launch.

The only way to work around this is to install a persistence helper into a system app, this helper can then be used to reregister TrollStore and its installed apps as "System" so that they become launchable again, an option for this is available in TrollStore settings.

On jailbroken iOS 14 when TrollHelper is used for installation, it is located in /Applications and will persist as a "System" app through icon cache reloads, therefore TrollHelper is used as the persistence helper on iOS 14.

## URL Scheme

As of version 1.3, TrollStore replaces the system URL scheme "apple-magnifier" (this is done so "jailbreak" detections can't detect TrollStore like they could if TrollStore had a unique URL scheme). This URL scheme can be used to install applications right from the browser, or to enable JIT from the app itself (only 2.0.12 and above), the format goes as follows:

- `apple-magnifier://install?url=<URL_to_IPA>`
- `apple-magnifier://enable-jit?bundle-id=<Bundle_ID>`

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

Afterwards you can use the [spawnRoot function in TSUtil.m](./Shared/TSUtil.m#L79) to spawn the binary as root.

### Things that are not possible using TrollStore

- Getting proper platformization (`TF_PLATFORM` / `CS_PLATFORMIZED`)
- Spawning a launch daemon (Would need `CS_PLATFORMIZED`)
- Injecting a tweak into a system process (Would need `TF_PLATFORM`, a userland PAC bypass and a PMAP trust level bypass)

### Compilation

To compile TrollStore, ensure [theos](https://theos.dev/docs/installation) is installed. Additionaly ensure [brew](https://brew.sh/) is installed and install [libarchive](https://formulae.brew.sh/formula/libarchive) from brew.

## Credits and Further Reading

[@alfiecg_dev](https://twitter.com/alfiecg_dev/) - Found the CoreTrust bug that allows TrollStore to work through patchdiffing and worked on automating the bypass.

Google Threat Analysis Group - Found the CoreTrust bug as part of an in-the-wild spyware chain and reported it to Apple.

[@LinusHenze](https://twitter.com/LinusHenze) - Found the installd bypass used to install TrollStore on iOS 14-15.6.1 via TrollHelperOTA, as well as the original CoreTrust bug used in TrollStore 1.0.

[Fugu15 Presentation](https://youtu.be/rPTifU1lG7Q)

[Write-Up on the first CoreTrust bug with more information](https://worthdoingbadly.com/coretrust/).
