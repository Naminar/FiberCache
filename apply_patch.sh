#!/bin/bash
git submodule init
git submodule update 
cd FakeRAM2.0/
git apply ../fake-sram.patch