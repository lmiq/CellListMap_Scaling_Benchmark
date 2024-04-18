if length(ARGS) != 1 || !isfile(ARGS[1])
    println("""

        Run with, for example:
        julia scaling_plots.jl ./final_0.7.1_nthreads.dat
    """)
    exit()
end

import Pkg
Pkg.activate(".")

using Plots
using EasyFit
using LaTeXStrings
using DelimitedFiles
using ColorSchemes
using TOML
using DataStructures
using CellListMap

ENV["GKSwstype"]="nul"

plot_font = "Computer Modern"
default(
    fontfamily=plot_font,
    linewidth=2.5, 
    markersize=5.0,
    framestyle=:box, 
    label=nothing, 
    palette=:thermal,
    alpha=1.0
)
scalefontsizes() 
#scalefontsizes(1.3)


file = ARGS[1]
data = OrderedDict(sort(TOML.parsefile(file),by=x->parse(Int,x)))

p = plot(layout=(2,2))

for (sp,a) in pairs(["time map", "time scr", "total time scr", "total time up1"])
  titles = ["map time", "cell list time", "total time", "total update time" ]
  ic = 0
  for n in values(last(first(data))["N"])
      i = findfirst(isequal(n),values(last(first(data))["N"]))
      t = Float64[]
      ic += 1
      for np in keys(data)
          push!(t,data["$np"]["$a"][i])
  #        push!(t,100 * data[np]["0 gc scr"][i] / (data[np]["0 time scr"][i] + data[np]["3 time map"][i]))
      end
      np = collect(parse.(Int,keys(data)))
      color = get(ColorSchemes.rainbow,ic/length(np))
      fit = fitlinear(inv.(np[1:4]),t[1:4])
      x = log2.(np)
      y = log2.(t[1] ./ t)
  #    y = log2.(fit.a ./ (t .- fit.b))
      scatter!(p, subplot=sp, x, y, color=color)#, label="$(Int(n))")
      plot!(p, subplot=sp, x, y, color=color)#, label="$(Int(n))")
  end
  
  plot!(p,subplot=sp,[0,128],[0,128],label=:none,color=:black,style=:dash)
  
  np = [ div(10^n,m) for m in (2,1), n in (4,5,6,7) ]
  scatter!(p,subplot=sp, 
      [-10],[-10],
      color=get(ColorSchemes.rainbow,2/length(np)),
      label=L"10^4~\textrm{particles}"
  )
  scatter!(p, subplot=sp,[NaN],[NaN],
      color=get(ColorSchemes.rainbow,1/length(np)),
      label=L"~~\vdots"
  )
  scatter!(p, subplot=sp, [-10],[-10],
      color=get(ColorSchemes.rainbow,4/length(np)),
      label=L"10^5~\textrm{particles}"
  )
  scatter!(p, subplot=sp, [NaN],[NaN],
      color=get(ColorSchemes.rainbow,1/length(np)),
      label=L"~~\vdots"
  )
  scatter!(p, subplot=sp,[-10],[-10],
      color=get(ColorSchemes.rainbow,1),
      label=L"10^7~\textrm{particles}"
  )
  
  ticks = collect(n for n in 0:7)
  ticks_labels = collect(latexstring("$(2^n)") for n in 0:7)
  plot!(p, subplot=sp,
      xlims=(-0.2,7),
      ylims=(-0.2,7),
      yticks=(ticks, ticks_labels),
      xticks=(ticks, ticks_labels),
      xlabel="Number of threads",
      ylabel="Speedup",
  #    ylabel="%GC",
  #    legend=nothing,
      #legend=:topright,
      legend=:topleft,
      title=titles[sp],
      size=(600,600),
  )
end

savefig("./$(ARGS[1][1:end-4]).png")
savefig("./$(ARGS[1][1:end-4]).pdf")

