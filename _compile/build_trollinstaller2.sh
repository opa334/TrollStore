if [ ! -f "$(pwd)/target/Developer.ipa" ]; then
    echo "[!] Developer IPA doesn't exist! Please place it in _compile/target/Developer.ipa"
    exit
fi

cd ../TrollInstaller2
make clean
make package
cd -

mkdir -p ./out/devpwn

lipo -thin arm64e ../TrollInstaller2/.theos/obj/debug/TrollInstaller2.app/TrollInstaller2 -output ./out/pwn_arm64e
ldid -S -M -Kcert.p12 ./out/pwn_arm64e

unzip target/Developer.ipa -d ./out/devpwn

./pwnify_compiled ./out/devpwn/Payload/Developer.app/Developer ./out/pwn_arm64e
rm ./out/pwn_arm64e

cd ./out/devpwn
zip -mvr devpwn.ipa *
cd -

cp ./out/devpwn/devpwn.ipa ./out/DeveloperInstaller.ipa
rm -rf ./out/devpwn
