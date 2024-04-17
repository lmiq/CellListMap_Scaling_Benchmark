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

# maximum number of samples and evaluation per sample in benchmarks
nsamples=1
nevals=1

function updict!(dict,i,str,bench) 
    push!(dict["$i time $str"],mean(bench.time)/tunit)
    push!(dict["$i mem $str"],mean(bench.bytes)/memunit)
    push!(dict["$i gc $str"],mean(bench.gctime)/memunit)
end

function scaling(np;save=true,parallel=true)
    nthreads = Threads.nthreads()
    data = OrderedDict(
        "N" => Int[],
        "0 time scr" => Float64[],
        "1 time up0" => Float64[],
        "2 time up1" => Float64[],
        "3 time map" => Float64[],
        "0 mem scr" => Float64[],
        "1 mem up0" => Float64[],
        "2 mem up1" => Float64[],
        "3 mem map" => Float64[],
        "0 gc scr" => Float64[],
        "1 gc up0" => Float64[],
        "2 gc up1" => Float64[],
        "3 gc map" => Float64[],
        "total time scr" => Float64[],
        "total time up0" => Float64[],
        "total time up1" => Float64[],
        "gc % scr" => Float64[],
    )
    if save 
        log = open("out.log","w")
    end
    println(" NUMBER OF THREADS = ", Threads.nthreads())
    for N in np
        println("Benchmarking with N = ", N," ... ")
        save && println(log,"Benchmarking with N = ", N," ... ")
        push!(data["N"],N)
        GC.gc()

        # Pre-preparation (small system)
        println("   - Small system preparation ...")
        x_min, box_min = CellListMap.xatomic(5000)
        cl0 = CellList(x_min,box_min,parallel=false)
        aux0 = CellListMap.AuxThreaded(cl0)

        # True system
        x, box = CellListMap.xatomic(N)

        # Build cell list from scratch
        println(" 0 - Cell list from scratch ...")
        cl = CellList(x,box,parallel=parallel)
        t0 = @timed CellList(x,box,parallel=parallel)
        updict!(data,0,"scr",t0)
        save && println(log,t0)

        # Build cell list by updating small system
        println(" 1 - Updating small system list ...")
        t1 = @timed UpdateCellList!(x,box,cl0,aux0,parallel=parallel)
        updict!(data,1,"up0",t1)
        save && println(log,t1)
        
        # Build cell list by updating the same system 
        println(" 2 - Updating true system list ...")
        aux = CellListMap.AuxThreaded(cl)
        t2 = @timed UpdateCellList!(x,box,cl,aux,parallel=parallel)
        updict!(data,2,"up1",t2)
        save && println(log,t2)

        # Compute potential energy
        println(" 3 - Computing potential ...")
        t3 = @timed let box=box, cl=cl, parallel=parallel
             map_pairwise((x,y,i,j,d2,u) -> ulj(d2,u), 0., box, cl, parallel=parallel)
        end
        updict!(data,3,"map",t3)
        save && println(log,t3)

        push!(data["total time scr"], (mean(t0.time) + mean(t3.time))/tunit)
        push!(data["total time up0"], (mean(t1.time) + mean(t3.time))/tunit)
        push!(data["total time up1"], (mean(t2.time) + mean(t3.time))/tunit)
        push!(data["gc % scr"], 100 * (mean(t0.gctime) + mean(t3.gctime)) / (mean(t0.time) + mean(t3.time)))

        println("Finished.")
        save && println(log," finished.")
        flush(stdout)
    end
    save && close(log)

    if save
        output = "./nthreads/"*@sprintf("%03i",nthreads)*".dat"
        file = open(output,"w")
        TOML.print(file,data)
        close(file)
    end
    return data
end

# precompile everything
scaling([5000],save=false)

# run benchmark
np = [ m*10^n for m in (1,2,4,6,8), n in (4,5,6,7) ]
data = scaling(np,save=true)



