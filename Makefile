TOPTARGETS := all clean

$(TOPTARGETS): pre_build make_roothelper make_trollstore make_trollhelper make_trollhelper_package assemble_trollstore make_trollhelper_embedded build_installer15 build_installer64e

pre_build:
		@rm -rf ./_build 2>/dev/null || true
		@mkdir -p ./_build

make_roothelper:
		@$(MAKE) -C ./RootHelper FINALPACKAGE=1 $(MAKECMDGOALS)

make_trollstore:
		@$(MAKE) -C ./TrollStore FINALPACKAGE=1 $(MAKECMDGOALS)

make_trollhelper:
		@$(MAKE) -C ./TrollStore FINALPACKAGE=1 $(MAKECMDGOALS)

ifneq ($(MAKECMDGOALS),clean)

make_trollhelper_package:
		@$(MAKE) clean -C ./TrollHelper
		@cp ./RootHelper/.theos/obj/trollstorehelper ./TrollHelper/Resources/trollstorehelper
		@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 package $(MAKECMDGOALS)
		@rm ./TrollHelper/Resources/trollstorehelper

make_trollhelper_embedded:
		@$(MAKE) clean -C ./TrollHelper
		@$(MAKE) -C ./TrollHelper FINALPACKAGE=1 EMBEDDED_ROOT_HELPER=1 $(MAKECMDGOALS)

assemble_trollstore:
		@cp cert.p12 ./TrollStore/.theos/obj/TrollStore.app/cert.p12
		@cp ./RootHelper/.theos/obj/trollstorehelper ./TrollStore/.theos/obj/TrollStore.app/trollstorehelper
		@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./TrollStore/.theos/obj/TrollStore.app/PersistenceHelper
		@export COPYFILE_DISABLE=1
		@tar -czvf ./_build/TrollStore.tar -C ./TrollStore/.theos/obj TrollStore.app

build_installer15:
		@mkdir -p ./_build/tmp15
		@unzip ./Victim/InstallerVictim.ipa -d ./_build/tmp15
		@cp ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper ./_build/TrollStorePersistenceHelperToInject
		@pwnify set-cpusubtype ./_build/TrollStorePersistenceHelperToInject 1
		@ldid -s -K./Victim/victim.p12 ./_build/TrollStorePersistenceHelperToInject
		APP_PATH=$$(find ./_build/tmp15/Payload -name "*" -depth 1) ; \
		APP_NAME=$$(basename $$APP_PATH) ; \
		BINARY_NAME=$$(echo "$$APP_NAME" | cut -f 1 -d '.') ; \
		echo $$BINARY_NAME ; \
		pwnify pwn ./_build/tmp15/Payload/$$APP_NAME/$$BINARY_NAME ./_build/TrollStorePersistenceHelperToInject
		@pushd ./_build/tmp15 ; \
		zip -vrD ../../_build/TrollHelper_iOS15.ipa * ; \
		popd
		@rm ./_build/TrollStorePersistenceHelperToInject
		@rm -rf ./_build/tmp15

build_installer64e:
		@mkdir -p ./_build/tmp64e
		@unzip ./Victim/InstallerVictim.ipa -d ./_build/tmp64e
		APP_PATH=$$(find ./_build/tmp64e/Payload -name "*" -depth 1) ; \
		APP_NAME=$$(basename $$APP_PATH) ; \
		BINARY_NAME=$$(echo "$$APP_NAME" | cut -f 1 -d '.') ; \
		echo $$BINARY_NAME ; \
		pwnify pwn64e ./_build/tmp64e/Payload/$$APP_NAME/$$BINARY_NAME ./TrollHelper/.theos/obj/TrollStorePersistenceHelper.app/TrollStorePersistenceHelper
		@pushd ./_build/tmp64e ; \
		zip -vrD ../../_build/TrollHelper_arm64e.ipa * ; \
		popd
		@rm -rf ./_build/tmp64e
endif

.PHONY: $(TOPTARGETS) pre_build assemble_trollstore make_trollhelper_package make_trollhelper_embedded build_installer15 build_installer64e