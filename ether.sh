script=$1 
file=$2
while true ; do
    if [ `qstat -u lmartine | grep lmartine | wc -l` -ge 1 ]; then
        sleep 2
        continue
    fi
    nt=`julia check.jl -- $file`
    if [ $nt -eq 0 ]; then
        break
    fi
    echo "Submitting job... $script with $nt"
    sed -e s/SCRIPT/$script/ teste.pbs > /tmp/tmp.pbs
    sed -e s/NTHREADS/$nt/ /tmp/tmp.pbs > /tmp/tmp2.pbs
    if [ $nt -eq 1 ]; then 
        nt=2
    fi
    qsub -q testes -l nodes=1:ncpus=$nt /tmp/tmp2.pbs
    sleep 10
done
