#!/bin/sh


ARCHS="arm64 x86_64"
DEPLOYMENT_TARGET="11.2"

LIPO="y"

CWD=`pwd`
BUILD_DIR="mpv-tvOS"
SOURCE="mpv"
FAT="fat"
THIN=$CWD/$BUILD_DIR/"thin"
SCRATCH=$CWD/$BUILD_DIR/"scratch"

if [ "$*" ]
then
    ARCHS="$*"
    if [ $# -eq 1 ]
    then
        # skip lipo
        LIPO=
    fi
fi


if [ ! -r $SOURCE ]
then
    echo 'mpv source not found. Trying to download...'
    git clone https://github.com/mpv-player/mpv.git
    cd ./mpv/
    ./bootstrap.py
else
    cd ./mpv/
fi

# hacky way to fix typedef redefinition errors for 32-bit builds
# PATTERN="typedef ptrdiff_t GLsizeiptr;"
# REPLACE="#if defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__) && (__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__ > 1060)\ntypedef ptrdiff_t GLsizeiptr;\n#else\ntypedef intptr_t GLsizeiptr;\n#endif\n"
# perl -pi -e "s/$PATTERN/$REPLACE/" /Users/Josh/Projects/mpv-demo/contrib/mpv/video/out/opengl/gl_headers.h


#./waf clean
#./waf distclean

for ARCH in $ARCHS
do

    echo "Building $ARCH..."

    if [ "$ARCH" = "i386" -o "$ARCH" = "x86_64" ]
    then
        PLATFORM="appletvsimulator"
    else 						
        PLATFORM="appletvos"
    fi

    export PATH="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/:$PATH"
    export SDKPATH="$(xcodebuild -sdk $PLATFORM -version Path)"
    export CFLAGS="-isysroot $SDKPATH -arch $ARCH -mtvos-version-min=$DEPLOYMENT_TARGET -fembed-bitcode \
-I$CWD/FFmpeg-tvOS/thin/$ARCH/include"
    export LDFLAGS="-isysroot $SDKPATH -arch $ARCH -Wl,-tvos_version_min,$DEPLOYMENT_TARGET -lbz2 \
-L$CWD/FFmpeg-tvOS/thin/$ARCH/lib"

    echo $CFLAGS
    echo $LDFLAGS

#--enable-videotoolbox-gl
    OPTION_FLAGS=" --disable-cplayer --disable-lcms2 --disable-lua --disable-libass --enable-libmpv-static --enable-ios-gl --enable-gl \
--out=$SCRATCH/$ARCH --prefix=$THIN/$ARCH"

    export PKG_CONFIG_PATH="$CWD/FFmpeg-tvOS/thin/$ARCH/lib/pkgconfig"

    echo "Configuring with options $OPTION_FLAGS"

    ./waf configure $OPTION_FLAGS || exit 1
    ./waf build -j4 || exit 1
    ./waf install || exit 1

done

cd ./..

if [ "$LIPO" ]
then
    echo "building fat binaries..."
    set - $ARCHS
    CWD=`pwd`/$BUILD_DIR
    mkdir -p $CWD/$FAT/lib
    cd $THIN/$1/lib
for LIB in *.a
do
    cd $CWD
    echo lipo -create `find $THIN -name $LIB` -output $CWD/$FAT/lib/$LIB 1>&2
    lipo -create `find $THIN -name $LIB` -output $CWD/$FAT/lib/$LIB || exit 1
done

    cd $CWD
    cp -rf $THIN/$1/include $CWD/$FAT
fi


echo Done


