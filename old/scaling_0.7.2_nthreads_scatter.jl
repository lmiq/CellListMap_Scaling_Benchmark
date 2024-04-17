import Pkg
Pkg.activate(temp=true)

Pkg.add([
    "FastPow",
    "BenchmarkTools",
    "Statistics",
    "Printf",
    "TOML",
    "DataStructures",
    "ThreadPinning",
    "Hwloc",
])

using ThreadPinning, Hwloc
pinthreads(:scatter)

using CellListMap

include("./scaling.jl")

# precompile everything
output_file="dummy.dat"
scaling([5000],output_file,save=false)

# run benchmark
np = [ div(10^n,m) for m in (2,1), n in (4,5,6,7) ]
output_file="final_0.7.2_nthreads_scatter.dat"
nb = (0,0)

scaling(np,output_file,save=true,nb_glob=nb)
