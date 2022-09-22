#!/bin/sh

if [ -d "./out" ]
then
    rm -rf ./out
fi
mkdir -p ./out

# Step one: Compile TrollStore

cd ../Store
make clean
make FINALPACKAGE=1
cd -

cp -r ../Store/.theos/obj/TrollStore.app ./out/TrollStore.app
ldid -S -M -Kcert.p12 ./out/TrollStore.app

# Step two: Compile and permasign helper

cd ../Helper
make clean
make FINALPACKAGE=1
cd -

cp ../Helper/.theos/obj/trollstorehelper ./out/TrollStore.app/trollstorehelper
ldid -S -M -Kcert.p12 ./out/TrollStore.app/trollstorehelper

# Step three: Compile and permasign persistence helper

# (copy helper into persistence helper)
cp ./out/TrollStore.app/trollstorehelper ../PersistenceHelper/Resources/trollstorehelper

cd ../PersistenceHelper
make clean
make package FINALPACKAGE=1
cd -

rm ../PersistenceHelper/Resources/trollstorehelper

cp ../PersistenceHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./out/TrollStore.app/PersistenceHelper
ldid -S -M -Kcert.p12 ./out/TrollStore.app/PersistenceHelper

# Step four: tar everything

cd out
COPYFILE_DISABLE=1 tar -czvf TrollStore.tar ./TrollStore.app
rm -rf ./TrollStore.app
cd -

if [[ $1 == "installer" ]]; then
    # Step five: compile installer
    xcodebuild -project ../Installer/TrollInstaller/TrollInstaller.xcodeproj -scheme TrollInstaller -destination generic/platform=iOS -archivePath ./out/Installer.xcarchive archive

    if [[ -f "./out/Installer.xcarchive/Products/Applications/TrollInstaller.app/embedded.mobileprovision" ]]; then
        rm ./out/Installer.xcarchive/Products/Applications/TrollInstaller.app/embedded.mobileprovision
    fi

    ldid -s ./out/Installer.xcarchive/Products/Applications/TrollInstaller.app
    mkdir ./out/Payload
    mv ./out/Installer.xcarchive/Products/Applications/TrollInstaller.app ./out/Payload/TrollInstaller.app
    cd out
    zip -vr TrollInstaller.ipa Payload
    cd -
    rm -rf ./out/Payload
    rm -rf ./out/Installer.xcarchive
fi