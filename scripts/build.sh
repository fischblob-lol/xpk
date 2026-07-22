#!/bin/sh

# zig build -Dtarget=x86_64-linux-gnu -Dsmall (yo do this if on linux, because embeding libc adds around 35 mb of anything)
zig build -Dsmall=true
strip zig-out/bin/xpk
