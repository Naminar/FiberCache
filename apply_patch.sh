#!/bin/bash
git submodule init
git submodule update 
cd FakeRAM2.0/

if git apply --check ../fake-sram.patch 2>/dev/null; then
    echo "Patch can be applied cleanly. Applying now..."
    git apply ../fake-sram.patch
    echo "Patch applied successfully."
fi