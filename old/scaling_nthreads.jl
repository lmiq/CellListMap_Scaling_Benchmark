using CellListMap
using FastPow
using BenchmarkTools
using Statistics
using Printf
using TOML
using DataStructures

ulj(d2,u) = @fastpow u += 4*(1/d2^6 - 1/d2^3)

tunit = 10^9 # to seconds
memunit = 1024^2 # to MiB

function updict!(dict,str,bench) 
    push!(dict["time $str"],mean(bench.times)/tunit)
    push!(dict["mem $str"],mean(bench.memory)/memunit)
    push!(dict["gc $str"],mean(bench.gctimes)/memunit)
end

function scaling(np;save=true,parallel=true,nb=(0,0))
    nthreads = Threads.nthreads()
    data = OrderedDict(
        "N" => Int[],
        "time scr" => Float64[],
        "time up0" => Float64[],
        "time up1" => Float64[],
        "time map" => Float64[],
        "mem scr" => Float64[],
        "mem up0" => Float64[],
        "mem up1" => Float64[],
        "mem map" => Float64[],
        "gc scr" => Float64[],
        "gc up0" => Float64[],
        "gc up1" => Float64[],
        "gc map" => Float64[],
        "total time scr" => Float64[],
        "total time up0" => Float64[],
        "total time up1" => Float64[],
        "gc % scr" => Float64[],
        "nbatches.build_cell_lists" => Int[],
        "nbatches.map_computation" => Int[],
    )
    if save 
        log = open("out.log","w")
    end
    for N in np
        println("Benchmarking with N = ", N," ... ")
        save && println(log,"Benchmarking with N = ", N," ... ")
        push!(data["N"],N)
        GC.gc()
    
        nb = (Threads.nthreads(),Threads.nthreads())

        # True system
        x, box = CellListMap.xatomic(N)

        # Build cell list from scratch
        cl = CellList(x,box,parallel=parallel,nbatches=nb)

        nb = (cl.nbatches.build_cell_lists, cl.nbatches.map_computation)
        @show Threads.nthreads(), nb
        t0 = @benchmark CellList($x,$box,parallel=$parallel)
        updict!(data,"scr",t0)
        @show t0
        save && println(log,t0)

        # Build cell list by updating the same system for the first time
        aux0 = CellListMap.AuxThreaded(cl)
        cl = CellList(x,box,parallel=parallel,nbatches=nb)
        t1 = @benchmark UpdateCellList!($x,$box,cl,aux,parallel=$parallel) setup=(cl=deepcopy($cl); aux=deepcopy($aux0)) evals=1
        updict!(data,"up0",t1)
        @show t1
        save && println(log,t1)
        
        # Build cell list by updating the same system for the second time and next
        aux = CellListMap.AuxThreaded(cl)
        cl = UpdateCellList!(x,box,cl,aux,parallel=parallel) 
        t2 = @benchmark UpdateCellList!($x,$box,$cl,$aux,parallel=$parallel)
        updict!(data,"up1",t2)
        @show t2
        save && println(log,t2)

        # Compute potential energy
        t3 = @benchmark let box=$box, cl=$cl, parallel=$parallel
             map_pairwise((x,y,i,j,d2,u) -> ulj(d2,u), 0., box, cl, parallel=parallel)
        end
        updict!(data,"map",t3)
        @show t3
        save && println(log,t3)

        push!(data["total time scr"], (mean(t0.times) + mean(t3.times))/tunit)
        push!(data["total time up0"], (mean(t1.times) + mean(t3.times))/tunit)
        push!(data["total time up1"], (mean(t2.times) + mean(t3.times))/tunit)
        push!(data["gc % scr"], 100 * (mean(t0.gctimes) + mean(t3.gctimes)) / (mean(t0.times) + mean(t3.times)))
        push!(data["nbatches.build_cell_lists"], nb[1])
        push!(data["nbatches.map_computation"], nb[2])

        println(" finished.")
        save && println(log," finished.")
        flush(stdout)
    end
    save && close(log)

    if save
#        output = "./nthreads/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./build_with_8_batches/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./set_batches/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./nbatches_eq_nthreads/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./newmerge2/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./newmerge2_t1/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./newmerge2_final/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./locks_heuristic/"*@sprintf("%03i",nthreads)*".dat"
#        output = "./locks_nthreads/"*@sprintf("%03i",nthreads)*".dat"
        output = "./final_0.7.1/"*@sprintf("%03i",nthreads)*".dat"
        file = open(output,"w")
        TOML.print(file,data)
        close(file)
    end
    return data
end

# precompile everything
scaling([5000],save=false)

# run benchmark
np = [ div(10^n,m) for m in (2,1), n in (4,5,6,7) ]
data = scaling(np,save=true)

