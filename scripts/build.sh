#!/bin/sh

zig build -Dsmall=true
strip zig-out/bin/xpk
