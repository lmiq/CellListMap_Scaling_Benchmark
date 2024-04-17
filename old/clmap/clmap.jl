import Pkg
Pkg.UPDATED_REGISTRY_THIS_SESSION[] = true
Pkg.activate(".")
Pkg.develop("CellListMap")
using CellListMap

nbatches=(64,64)
x, box = CellListMap.xatomic(10^4)
cl = CellList(x,box,nbatches=nbatches)
aux = CellListMap.AuxThreaded(cl)

print(" Update cell list: ") 
@btime UpdateCellList!($x,$box,cl,aux) setup=(cl=deepcopy($cl),aux=deepcopy($aux)) evals=1

print(" Map computation:  ")
@btime map_pairwise((x,y,i,j,d2,out) -> out += d2, 0., $box, $cl)




