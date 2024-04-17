julia=/home/lovelace/proj/proj864/lmartine/.juliaup/bin/julia
workdir=/home/lovelace/proj/proj864/lmartine/CellListMap

cd $workdir
script=scaling_nthreads.jl

#for nthreads in 110 64 32 16 8 4 2 1 ; do
for nthreads in 4 2 ; do
    JULIA_EXCLUSIVE=1 $julia -t $nthreads $script
done

echo "Finished!"
