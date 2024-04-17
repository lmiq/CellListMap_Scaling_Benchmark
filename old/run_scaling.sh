#!/bin/bash
julia=/home/lovelace/proj/proj864/lmartine/.local/bin/julia
workdir=/home/lovelace/proj/proj864/lmartine/CellListMap
#cd /home/lovelace/proj/proj864/lmartine/.julia/dev/CellListMap
#/usr/bin/git checkout main
cd $workdir
JULIA_EXCLUSIVE=1 $julia -t 128 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 64 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 32 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 16 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 8 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 4 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 2 scaling.jl
JULIA_EXCLUSIVE=1 $julia -t 1 scaling.jl
