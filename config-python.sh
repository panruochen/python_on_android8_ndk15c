#!/bin/bash

set -e

#targetOs=x86_64-linux
targetOs=${1:-android8}

buildBoxDir=$(cd $(dirname $0) && pwd)
buildDir=${buildBoxDir}/__build/libffi/${targetOs}
installDir=${buildBoxDir}/__install/${targetOs}
HOST_PY_INSTALL_DIR=/opt/Python3.7.4-v2

createAndEnter() {
	local d="$1"
	mkdir -p "$1" && cd "$1"
}

ANDROID_NDK=/home/shutils/android-ndk-r15c
ANDROID_API=24
CROSS_COMPILE=${ANDROID_NDK}/toolchains/aarch64-linux-android-4.9/prebuilt/linux-x86_64/bin/aarch64-linux-android-
androidNdkSysRoot1=${ANDROID_NDK}/sysroot
androidNdkSysRoot2=${ANDROID_NDK}/platforms/android-${ANDROID_API}/arch-arm64
androidCcFlags="--sysroot=${androidNdkSysRoot2} -DANDROID -isystem ${androidNdkSysRoot1}/usr/include -isystem ${androidNdkSysRoot1}/usr/include/aarch64-linux-android -D__ANDROID_API__=${ANDROID_API} -DANDROID -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -Wa,--noexecstack -Wformat -Werror=format-security -O2 -DNDEBUG -Wall -Wno-unknown-pragmas -Wno-unused -Wno-char-subscripts -Wno-c++11-narrowing -Werror=uninitialized -Werror=return-type"

###   /home/shutils/android-ndk-r15c/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++ --target=aarch64-none-linux-android --gcc-toolchain=/home/shutils/android-ndk-r15c/toolchains/aarch64-linux-android-4.9/prebuilt/linux-x86_64 --sysroot=/home/shutils/android-ndk-r15c/sysroot -fPIC -isystem /home/shutils/android-ndk-r15c/sysroot/usr/include/aarch64-linux-android -D__ANDROID_API__=26 -g -DANDROID -ffunction-sections -funwind-tables -fstack-protector-strong -no-canonical-prefixes -Wa,--noexecstack -Wformat -Werror=format-security   -std=c++11 -O2 -DNDEBUG -lz -llog -landroid -lstdc++ -Wl,--exclude-libs,libgcc.a --sysroot /home/shutils/android-ndk-r15c/platforms/android-26/arch-arm64 -Wl,--build-id -Wl,--warn-shared-textrel -Wl,--fatal-warnings -Wl,--no-undefined -Wl,-z,noexecstack -Qunused-arguments -Wl,-z,relro -Wl,-z,now  -shared -Wl,-soname,libirs_lazybox.so -o libirs_lazybox.so CMakeFiles/irs_lazybox.dir/gitversion.cpp.o CMakeFiles/irs_lazybox.dir/v1.cpp.o /ws2/newsdk2.x/IsarKrnlPack/android8/lib/libopencv_world.so -lm "/home/shutils/android-ndk-r15c/sources/cxx-stl/gnu-libstdc++/4.9/libs/arm64-v8a/libsupc++.a" "/home/shutils/android-ndk-r15c/sources/cxx-stl/gnu-libstdc++/4.9/libs/arm64-v8a/libgnustl_shared.so" "/home/shutils/android-ndk-r15c/sources/cxx-stl/gnu-libstdc++/4.9/libs/arm64-v8a/libgnustl_shared.so" -nodefaultlibs -lgcc -lc -lm -ldl

configLibff_Arm64Android8()
{
	cd $buildDir

	env CC="${CROSS_PREFIX}gcc ${androidCcFlags}" \
../../../src/libffi/configure --host=aarch64-linux-android --build=x86_64-linux-gnu --prefix=$installDir
}

buildDir=${buildBoxDir}/__build/python/${targetOs}

configPython_host()
{
	createAndEnter $buildDir

../../../src/Python-3.7.4/configure --prefix=$HOST_PY_INSTALL_DIR \
	--disable-ipv6 --disable-profiling
}

configPython_Arm64Android8()
{
	local y unixCc
	local hostPyLibPyDir hostPyDistUtilsDir

	hostPyLibPyDir=$HOST_PY_INSTALL_DIR/lib/python3.7
	y=$hostPyLibPyDir/config-3.7m-x86_64-linux-gnu
	if [ -d "$y" ]; then
		mv "$y" $(dirname "$y")/__$(basename "$y") || true
		ln -sf $buildDir $y
	fi

	if [ ! -f $buildDir/Makefile.pre.in ]; then
		cp -dprfv ${buildBoxDir}/src/Python-3.7.4/* $buildDir
	fi
	createAndEnter $buildDir

	hostPyDistUtilsDir=$hostPyLibPyDir/distutils
	unixCc=$hostPyDistUtilsDir/unixccompiler.py

	if ! grep -q fix_for_android $unixCc; then
		cat >$hostPyDistUtilsDir/fix_for_android.py <<'__EOF__'
def fix_compile_args(cc_args) :
	cc_args_fixed = []
	for i in cc_args :
		if i.find("-I/usr/") != 0 :
			cc_args_fixed.append(i)
	return cc_args_fixed

def fix_link_args(ld_args) :
	ld_args_fixed = []
	for i in ld_args :
		if i.find("-L/usr/") != 0 :
			ld_args_fixed.append(i)
		if i == '-lpython3.7m' :
			ld_args_fixed.append('-Wl,--exclude-libs=libgcc')
			ld_args_fixed.append('-lgcc')
			ld_args_fixed.append(i)
	return ld_args_fixed
__EOF__
		cp -vf ${buildBoxDir}/unixccompiler_android8_patched.py $unixCc
	fi

	ccflags="${androidCcFlags} -I$buildBoxDir/__install/android8/include"

	ldlibs='-lpython3.7m -lffi'

	export PYTHONHOME=${HOST_PY_INSTALL_DIR}
env \
PYTHON_FOR_BUILD=${HOST_PY_INSTALL_DIR}/bin/python3.7 \
CC="${CROSS_COMPILE}gcc ${ccflags}" \
READELF="${CROSS_COMPILE}readelf" \
LDFLAGS="-fuse-ld=gold -Wl,--no-undefined -L${buildDir} -L$buildBoxDir/__install/android8/lib64 $ldlibs" \
LIBS="$ldlibs" \
LDLIBS="$ldlibs" \
../../../src/Python-3.7.4/configure --prefix=${buildBoxDir}/__install/python3.7-arm64 \
	ac_cv_file__dev_ptmx=no ac_cv_file__dev_ptc=no \
	--disable-ipv6 --disable-profiling --enable-shared --host=aarch64-linux-android --build=x86_64-linux
}



case "$targetOs" in
*android8)
#	configLibff_Arm64Android8
	configPython_Arm64Android8
	;;
x86_64-linux|*)
	configPython_host
	;;
esac


