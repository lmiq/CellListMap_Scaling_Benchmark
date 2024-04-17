julia_dir=/home/lovelace/proj/proj864/lmartine/local/bin/julia
basedir=/home/lovelace/proj/proj864/lmartine/CellListMap

julia=/home/lovelace/proj/proj864/lmartine/.local/bin/julia
workdir=/home/lovelace/proj/proj864/lmartine/CellListMap
cd $workdir

script=$1

#for nthreads in 110 64 32 16 8 4 2 1 ; do
for nthreads in 64 32 16 8 4 2 1 ; do
    JULIA_EXCLUSIVE=1 $julia -t $nthreads $script
done

echo "Finished!"
