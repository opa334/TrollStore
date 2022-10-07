#!/bin/sh
set -e

if [ ! -d "./out" ]
then
    mkdir -p ./out
fi

cd ../Installer/TrollInstaller2
make clean
make package
cd -

lipo -thin arm64e ../Installer/TrollInstaller2/.theos/obj/debug/TrollInstaller2.app/TrollInstaller2 -output ./out/pwn_arm64e
ldid -S -M -Kcert.p12 ./out/pwn_arm64e

mkdir ./out/devpwn
unzip target/Developer.ipa -d ./out/devpwn

./pwnify_compiled ./out/devpwn/Payload/Developer.app/Developer ./out/pwn_arm64e
rm ./out/pwn_arm64e

cd ./out/devpwn
zip -vr devpwn.ipa *
cd -

cp ./out/devpwn/devpwn.ipa ./out/DeveloperInstaller.ipa
rm -rf ./out/devpwn