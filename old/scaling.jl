#import Pkg
#Pkg.activate(".")

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

function scaling(np,output_file;save=true,parallel=true,nb_glob=(0,0))
    nthreads = Threads.nthreads()
    datakey="$nthreads"
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
    for N in np
        nb = nb_glob
        done = findfirst(isequal(N),data["N"])
        if !isnothing(done)
            println("Data found, skipping")
            continue
        end
    
        println("Benchmarking with N = ", N," ... ")
        save && println(log,"Benchmarking with N = ", N," ... ")
        push!(data["N"],N)
        GC.gc()
    
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
