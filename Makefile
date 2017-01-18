XCODE_DEVELOPER = $(shell xcode-select --print-path)
IOS_PLATFORM ?= iPhoneOS

# Pick latest SDK in the directory
IOS_PLATFORM_DEVELOPER = ${XCODE_DEVELOPER}/Platforms/${IOS_PLATFORM}.platform/Developer
IOS_SDK = ${IOS_PLATFORM_DEVELOPER}/SDKs/$(shell ls ${IOS_PLATFORM_DEVELOPER}/SDKs | sort -r | head -n1)

all: lib/libspatialite.a
lib/libspatialite.a: build_arches
	mkdir -p lib
	mkdir -p include

	# Copy includes
	cp -R build/iphoneos/armv7/include/geos include
	cp -R build/iphoneos/armv7/include/spatialite include
	cp -R build/iphoneos/armv7/include/*.h include

	# Make fat libraries for all architectures
	for file in build/iphoneos/armv7/lib/*.a; \
		do name=`basename $$file .a`; \
		/Library/Developer/CommandLineTools/usr/bin/lipo -create \
			-arch armv7 build/iphoneos/armv7/lib/$$name.a \
			-arch armv7s build/iphoneos/armv7s/lib/$$name.a \
			-arch arm64 build/iphoneos/arm64/lib/$$name.a \
			-arch i386 build/iphoneos/i386/lib/$$name.a \
			-arch x86_64 build/iphoneos/x86_64/lib/$$name.a \
			-output lib/$$name.a \
		; \
		done;

	for file in build/watchos/armv7k/lib/*.a; \
		do name=`basename $$file .a`; \
		/Library/Developer/CommandLineTools/usr/bin/lipo -create \
			-arch armv7k build/watchos/armv7k/lib/$$name.a \
			-arch i386 build/watchos/i386/lib/$$name.a \
			-output lib/$${name}_watchos.a \
		; \
		done;
# Build separate architectures
build_arches:
	${MAKE} arch ARCH=i386 IOS_PLATFORM=WatchSimulator HOST=i386-apple-darwin OS_TYPE="watchos" MIN_OS_VERSION="3.0"
	${MAKE} arch ARCH=armv7k IOS_PLATFORM=WatchOS HOST=arm-apple-darwin OS_TYPE="watchos" MIN_OS_VERSION="3.0"
	${MAKE} arch ARCH=armv7 IOS_PLATFORM=iPhoneOS HOST=arm-apple-darwin OS_TYPE="iphoneos" MIN_OS_VERSION="7.0"
	${MAKE} arch ARCH=armv7s IOS_PLATFORM=iPhoneOS HOST=arm-apple-darwin OS_TYPE="iphoneos" MIN_OS_VERSION="7.0"
	${MAKE} arch ARCH=arm64 IOS_PLATFORM=iPhoneOS HOST=arm-apple-darwin OS_TYPE="iphoneos" MIN_OS_VERSION="7.0"
	${MAKE} arch ARCH=i386 IOS_PLATFORM=iPhoneSimulator HOST=i386-apple-darwin OS_TYPE="iphoneos" MIN_OS_VERSION="7.0"
	${MAKE} arch ARCH=x86_64 IOS_PLATFORM=iPhoneSimulator HOST=x86_64-apple-darwin OS_TYPE="iphoneos" MIN_OS_VERSION="7.0"

PREFIX = ${CURDIR}/build/${OS_TYPE}/${ARCH}
LIBDIR = ${PREFIX}/lib
BINDIR = ${PREFIX}/bin
INCLUDEDIR = ${PREFIX}/include

CXX = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang++
CC = ${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
CFLAGS = -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -fembed-bitcode -m${OS_TYPE}-version-min=${MIN_OS_VERSION} -g
CXXFLAGS = -stdlib=libc++ -std=c++11 -isysroot ${IOS_SDK} -I${IOS_SDK}/usr/include -arch ${ARCH} -I${INCLUDEDIR} -fembed-bitcode -m${OS_TYPE}-version-min=${MIN_OS_VERSION} -g
LDFLAGS = -stdlib=libc++ -isysroot ${IOS_SDK} -L${LIBDIR} -L${IOS_SDK}/usr/lib -arch ${ARCH} -m${OS_TYPE}-version-min=${MIN_OS_VERSION} -g

arch: ${LIBDIR}/libspatialite.a

${LIBDIR}/libspatialite.a: ${LIBDIR}/libgeos.a ${LIBDIR}/libproj.a ${LIBDIR}/libsqlite3.a ${CURDIR}/spatialite
	cd spatialite && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS} -liconv -lgeos -lgeos_c -lc++" ./configure --host=${HOST} --disable-freexl --prefix=${PREFIX} --with-geosconfig=${BINDIR}/geos-config --disable-shared && make clean install-strip

${CURDIR}/spatialite:
	curl http://www.gaia-gis.it/gaia-sins/libspatialite-4.4.0-RC0.tar.gz > spatialite.tar.gz
	tar -xzf spatialite.tar.gz
	rm spatialite.tar.gz
	mv libspatialite-4.4.0-RC0 spatialite
	patch -Np0 < spatialite.patch


${LIBDIR}/libproj.a: ${CURDIR}/proj
	cd proj && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="-${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" ./configure --host=${HOST} --prefix=${PREFIX} --disable-shared && make clean install

${CURDIR}/proj:
	curl http://download.osgeo.org/proj/proj-4.9.3.tar.gz > proj.tar.gz
	tar -xzf proj.tar.gz
	rm proj.tar.gz
	mv proj-4.9.3 proj
	patch -Np0 < proj.patch


${LIBDIR}/libgeos.a: ${CURDIR}/geos
	cd geos && env \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS}" \
	CXXFLAGS="-${CXXFLAGS}" \
	LDFLAGS="${LDFLAGS}" ./configure --host=${HOST} --prefix=${PREFIX} --disable-shared && make clean install

${CURDIR}/geos:
	curl http://download.osgeo.org/geos/geos-3.5.0.tar.bz2 > geos.tar.bz2
	tar -xzf geos.tar.bz2
	rm geos.tar.bz2
	mv geos-3.5.0 geos
	patch -Np0 < geos.patch


${LIBDIR}/libsqlite3.a: ${CURDIR}/sqlite3
	cd sqlite3 && env LIBTOOL=${XCODE_DEVELOPER}/Toolchains/XcodeDefault.xctoolchain/usr/bin/libtool \
	CXX=${CXX} \
	CC=${CC} \
	CFLAGS="${CFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	CXXFLAGS="${CXXFLAGS} -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_RTREE=1 -DSQLITE_ENABLE_FTS3=1 -DSQLITE_ENABLE_FTS3_PARENTHESIS=1" \
	LDFLAGS="-Wl,-arch -Wl,${ARCH} -arch_only ${ARCH} ${LDFLAGS}" \
	./configure --host=${HOST} --prefix=${PREFIX} --disable-shared --enable-static && make clean install

${CURDIR}/sqlite3:
	curl https://sqlite.org/2017/sqlite-autoconf-3160200.tar.gz > sqlite3.tar.gz
	tar xzvf sqlite3.tar.gz
	rm sqlite3.tar.gz
	mv sqlite-autoconf-3160200 sqlite3
	patch -Np0 < sqlite3.patch
	touch sqlite3

clean:
	rm -rf build geos proj spatialite sqlite3 include lib
