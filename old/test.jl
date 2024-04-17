using Base.Threads: @spawn, @threads
using LinearAlgebra: norm
using StaticArrays
using Test
using FLoops

# Parallel code for sum(norm.( x - y for x in x, y in y ))
function sumd_threads(x,y,nbatches,aux)
    @assert length(x)%nbatches == 0
    batchsize = length(x) ÷ nbatches 
    aux .= 0.
    @threads for ibatch in 1:nbatches
        ifirst = (ibatch-1)*batchsize + 1
        ilast = ibatch*batchsize
        begin
            acc = 0.
            for i in ifirst:ilast 
                for j in 1:length(y)
                    @inbounds acc += norm(y[j]-x[i])
                end
            end
            aux[ibatch] = acc
        end
    end
    return sum(aux)
end

function sumd_spawn(x,y,nbatches,aux)
    @assert length(x)%nbatches == 0
    batchsize = length(x) ÷ nbatches 
    aux .= 0
    @sync for ibatch in 1:nbatches
        ifirst = (ibatch-1)*batchsize + 1
        ilast = ibatch*batchsize
        @spawn begin
            acc = 0.
            for i in ifirst:ilast 
                for j in 1:length(y)
                    @inbounds acc += norm(y[j]-x[i])
                end
            end
            aux[ibatch] = acc
        end
    end
    return sum(aux)
end

function sumd_floop(x,y,nbatches)
    @floop ThreadedEx(basesize = div(length(x),nbatches)) for i in 1:length(x)
        for j in 1:length(y)
            d = norm(y[j]-x[i])
            @reduce( dsum = 0. + d )
        end
    end
    return dsum
end

function test(nbatches)
    x = [ rand(SVector{3,Float64}) for _ in 1:6400 ]
    y = [ rand(SVector{3,Float64}) for _ in 1:100 ]
    aux = zeros(nbatches)
    simple = sum(norm.( x - y for x in x, y in y )) 
    @test sumd_threads(x,y,nbatches,aux) ≈ simple 
    @test sumd_spawn(x,y,nbatches,aux) ≈ simple
    @test sumd_floop(x,y,nbatches) ≈ simple
    print("sumd threads: "), @btime sumd_threads($x,$y,$nbatches,$aux)
    print("sumd spawn:   "), @btime sumd_spawn($x,$y,$nbatches,$aux)
    print("floops:       "), @btime sumd_floop($x,$y,$nbatches)
    nothing
end


 
