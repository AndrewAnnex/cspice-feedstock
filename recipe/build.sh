#!/bin/bash

if [ "$(uname)" == "Darwin" ];
then
    LIBNAME=libcspice.66.dylib
    EXTRA_FLAGS="-dynamiclib -install_name @rpath/${LIBNAME}"
else
    LIBNAME=libcspice.so.66
    EXTRA_FLAGS="-shared -Wl,-soname,${LIBNAME}"
fi

# static library files names
CSPICENM=cspice.66.a
CSUPPTNM=csupport.66.a

#########################################
# Build Shared library
#########################################
#  cd to lib dir
cd ${SRC_DIR}/lib
#  rm static libraries, needed for next static build steps
rm cspice.a
rm csupport.a
#  compile c code
if [ "$CI" == "drone" ];
then
    ${CC} -Iinclude -c -fPIC -O2 -ansi -pedantic ./../src/cspice/*.c 
else
    ${CC} -Iinclude -c -fPIC -O2 -ansi -pedantic -m64 ./../src/cspice/*.c 
fi  
#  make the shared library
if [ "$CI" == "drone" ];
then
    ${CC} ${EXTRA_FLAGS} -fPIC -O2 -pedantic -o ${LIBNAME} *.o -lm
else
    ${CC} ${EXTRA_FLAGS} -fPIC -O2 -pedantic -m64 -o ${LIBNAME} *.o -lm
fi  

#  cd up to src directory
cd ${SRC_DIR}

#########################################
# Build Static library using NAIF scripts
#########################################
#  rebuild static library using NAIF scripts
export TKCOMPILER=${CC}
cd ${SRC_DIR}/src/cspice
if [ "$CI" == "drone" ];
then
    TKCOMPILEOPTIONS="-c -ansi -O2 -fPIC -DNON_UNIX_STDIO" TKLINKOPTIONS="-lm" ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh
else
    ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh
fi  
cd ${SRC_DIR}/src/csupport
if [ "$CI" == "drone" ];
then
    TKCOMPILEOPTIONS="-c -ansi -O2 -fPIC -DNON_UNIX_STDIO" TKLINKOPTIONS="-lm" ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh
else
    ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh
fi  
#  rename static libraries to include version number
cd ${SRC_DIR}/lib
cp cspice.a ${CSPICENM}
cp csupport.a ${CSUPPTNM}
#  cd up to src directory
cd ${SRC_DIR}

#########################################
# Build executables using NAIF scripts
#########################################
# rm all prebuilt executables to ensure we are building and testing new files
rm ${SRC_DIR}/exe/*
# cd into src directory
cd ${SRC_DIR}/src
# build each tool using NAIF scripts
if [ "$CI" == "drone" ];
then
    for i in *_c; do cd $i && TKCOMPILEOPTIONS="-c -ansi -O2 -fPIC -DNON_UNIX_STDIO" TKLINKOPTIONS="-lm" ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh && cd -; done
else
    for i in *_c; do cd $i && ${BUILD_PREFIX}/bin/tcsh ./mkprodct.csh && cd -; done
fi  
#  cd up to src directory
cd ${SRC_DIR}
#  remove cspice.a and csupport.a as we want those to be symlinked, don't do this earlier for tool building
rm ${SRC_DIR}/lib/cspice.a
rm ${SRC_DIR}/lib/csupport.a

#########################################
# deploy built products
#########################################
# Deploy the built shared libraries and executables
#  make the target directories
mkdir -p ${PREFIX}/include/cspice
mkdir -p ${PREFIX}/lib
mkdir -p ${PREFIX}/bin
#  copy the files to where they are needed
cp $(find $(find ${SRC_DIR} -name "exe" -type d) -type f) ${PREFIX}/bin
cp lib/${LIBNAME} ${PREFIX}/lib/
cp lib/${CSPICENM} ${PREFIX}/lib/
cp lib/${CSUPPTNM} ${PREFIX}/lib/
cp include/*.h ${PREFIX}/include/cspice/
#  finally make symbolic links for sans version file names
if [ "$(uname)" == "Darwin" ];
then
    ln -s ${PREFIX}/lib/${LIBNAME} ${PREFIX}/lib/libcspice.dylib
else
    ln -s ${PREFIX}/lib/${LIBNAME} ${PREFIX}/lib/libcspice.so
fi
ln -s ${PREFIX}/lib/${CSPICENM} ${PREFIX}/lib/cspice.a
ln -s ${PREFIX}/lib/${CSUPPTNM} ${PREFIX}/lib/csupport.a
