#!/bin/sh
set -e

if [ ! -d "./out" ]
then
    mkdir -p ./out
fi

if [ -d "./out/tmppwn" ]
then
    rm -rf ./out/tmppwn
fi

if [ -f "./out/TrollInstaller2_arm64e.ipa" ]
then
    rm ./out/TrollInstaller2_arm64e.ipa
fi

IS_PROCURSUS_LDID=0
LDID_OUTPUT=$(ldid)
case "procursus" in 
  *$LDID_OUTPUT*)
    IS_PROCURSUS_LDID=1
    ;;
esac

if [[ "$IS_PROCURSUS_LDID" -eq 0 ]]; then
	echo "ERROR: You are not using Procursus ldid, follow the guide to switch to it."
	exit 1
fi

mkdir ./out/tmppwn || true 2> /dev/null

cd ../Installer/TrollInstaller2
make clean
make package
cd - 2> /dev/null

lipo -thin arm64e ../Installer/TrollInstaller2/.theos/obj/debug/TrollInstaller2.app/TrollInstaller2 -output ./out/tmppwn/pwn_arm64e
ldid -S -M -Kcert.p12 ./out/tmppwn/pwn_arm64e

unzip ./target/InstallerVictim.ipa -d ./out/tmppwn

cd ./out/tmppwn/Payload
APP_NAME=$(find *.app -maxdepth 0)
BINARY_NAME=$(echo "$APP_NAME" | cut -f 1 -d '.')
cd - 2> /dev/null

if [ ! -f "./pwnify_compiled" ]
then
    curl https://raw.githubusercontent.com/LinusHenze/Fugu14/master/tools/pwnify_compiled --output ./pwnify_compiled
	xattr -c ./pwnify_compiled
	chmod +x ./pwnify_compiled
	codesign -f -s - ./pwnify_compiled
fi

./pwnify_compiled ./out/tmppwn/Payload/$APP_NAME/$BINARY_NAME ./out/tmppwn/pwn_arm64e
rm ./out/tmppwn/pwn_arm64e

cd ./out/tmppwn
zip -vr ../TrollInstaller2_arm64e.ipa *
cd -

rm -rf ./out/tmppwn