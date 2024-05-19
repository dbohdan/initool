#! /bin/sh
set -eu

mlton_ver=mlton-20210117-1.amd64-linux-glibc2.31

if ! [ -f "$mlton_ver".tgz ]; then
    wget --quiet https://github.com/MLton/mlton/releases/download/on-20210117-release/"$mlton_ver".tgz
fi
tar xf "$mlton_ver".tgz
PATH=$PATH:"$mlton_ver"/bin

make initool-static all
