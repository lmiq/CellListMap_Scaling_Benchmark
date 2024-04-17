using TOML
data = try 
    TOML.parsefile(ARGS[1])
catch
    Dict{String,Any}()
end
for nt in ["110","64","32","16","8","4","2","1"]
    if !haskey(data,nt)
        println(nt)
        exit()
    else
        if length(data[nt]["N"]) < 8 
            println(nt)
            exit()
        end
    end
end
println(0)
exit()
