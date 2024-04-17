import Pkg
Pkg.activate(".")

using CellListMap
using FastPow
#using BenchmarkTools
using Chairmarks
using Statistics
using Printf
using TOML
using DataStructures

import ThreadPinning
ThreadPinning.pinthreads(:cores)

ulj(d2,u) = @fastpow u += 4*(1/d2^6 - 1/d2^3)

tunit = 10^9 # to seconds
memunit = 1024^2 # to MiB

function updict!(dict,str,bench) 
    push!(dict["time $str"],mean(bench.times)/tunit)
    push!(dict["mem $str"],mean(bench.memory)/memunit)
    push!(dict["gc $str"],mean(bench.gctimes)/memunit)
end

function scaling(nbatches,n_particles,output_file;save=true)
    (first(nbatches) == last(nbatches)) || error("use first(nbatches) == last(nbatches)")
    n_used_threads = first(nbatches)
    datakey="$n_used_threads"
    results = try 
        OrderedDict(TOML.parsefile(output_file))
    catch
        Dict{String,Any}()
    end
    if haskey(results,datakey)
        data = results[datakey]
    else
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
    end
    if save 
        log = open("out.log","w")
    end
    for N in n_particles
        println("Benchmarking with N = ", N," ... ")
        save && println(log,"Benchmarking with N = ", N," ... ")
        push!(data["N"],N)
        GC.gc()
    
        # True system
        x, box = CellListMap.xatomic(N)

        # Build cell list from scratch
        cl = CellList(x,box,nbatches=nbatches)

        println(" Available threads: ", Threads.nthreads(), "; using = ", nbatches)
        t0 = @benchmark CellList($x,$box,nbatches=$nbatches)
        updict!(data,"scr",t0)
        @show t0
        save && println(log,t0)

        # Build cell list by updating the same system for the first time
        aux0 = CellListMap.AuxThreaded(cl)
        cl = CellList(x,box,nbatches=nbatches)
        t1 = @benchmark UpdateCellList!($x,$box,cl,aux) setup=(cl=deepcopy($cl); aux=deepcopy($aux0)) evals=1
        updict!(data,"up0",t1)
        @show t1
        save && println(log,t1)
        
        # Build cell list by updating the same system for the second time and next
        aux = CellListMap.AuxThreaded(cl)
        cl = UpdateCellList!(x,box,cl,aux) 
        t2 = @benchmark UpdateCellList!($x,$box,$cl,$aux)
        updict!(data,"up1",t2)
        @show t2
        save && println(log,t2)

        # Compute potential energy
        t3 = @benchmark let box=$box, cl=$cl
             map_pairwise((x,y,i,j,d2,u) -> ulj(d2,u), 0., box, cl)
        end
        updict!(data,"map",t3)
        @show t3
        save && println(log,t3)

        push!(data["total time scr"], (mean(t0.times) + mean(t3.times))/tunit)
        push!(data["total time up0"], (mean(t1.times) + mean(t3.times))/tunit)
        push!(data["total time up1"], (mean(t2.times) + mean(t3.times))/tunit)
        push!(data["gc % scr"], 100 * (mean(t0.gctimes) + mean(t3.gctimes)) / (mean(t0.times) + mean(t3.times)))
        push!(data["nbatches.build_cell_lists"], first(nbatches))
        push!(data["nbatches.map_computation"], last(nbatches))

        println(" finished.")
        if save 
            data_order = sort(1:length(data["N"]),by=i->data["N"][i])
            for key in keys(data)
                data[key] = data[key][data_order]
            end
            println(log," finished.")
            results[datakey] = data
            results = sort(results,by=x->parse(Int,x))
            for key in keys(results)
                results[key] = OrderedDict(results[key])
                results[key] = sort(results[key])
            end
            file = open(output_file,"w")
            TOML.print(file,results)
            close(file)
        end

        flush(stdout)
    end
    save && close(log)

    return nothing
end

#
# precompile everything
#
function main()
    output_file="final_$(pkgversion(CellListMap))_$(Threads.nthreads()).dat"
    if isfile(output_file)
        mv(output_file, output_file*".OLD",force=true)
    end

    # precompile
    scaling((Threads.nthreads(), Threads.nthreads()),[5000],"dummy.dat";save=false)

    # run benchmark
    n_particles = [ div(10^n,m) for m in (2,1), n in (4,5,6,7) ]

    for nthreads in [128, 64, 32, 16, 8, 4, 2, 1]
        if nthreads <= Threads.nthreads()
            nbatches = (nthreads, nthreads)
            scaling(nbatches,n_particles,output_file;save=true)
        end
    end
end

main()


