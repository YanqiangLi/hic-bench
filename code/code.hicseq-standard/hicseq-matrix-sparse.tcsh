#!/bin/tcsh
source ./code/code.main/custom-tcshrc     # shell settings

##
## USAGE: hicseq-template.tcsh OUTPUT-DIR PARAM-SCRIPT BRANCH OBJECT(S)
##

if ($#argv != 4) then
  grep '^##' $0
  exit
endif

set outdir = $1
set params = $2
set branch = $3
set objects = ($4)

# read variables from input branch
source ./code/code.main/scripts-read-job-vars $branch "$objects" "genome genome_dir"

# run parameter script
source $params

# create path
scripts-create-path $outdir/

# -------------------------------------
# -----  MAIN CODE BELOW --------------
# -------------------------------------

# Find path to input filtered reads
set filtered_reads = `echo $objects | tr ' ' '\n' | awk -v d=$branch '{print d"/"$0"/filtered.reg.gz"}'`

# Preprocess filtered reads
echo "Preprocessing filtered reads..." | scripts-send2err
scripts-smartcat $filtered_reads | cut -f2- | cut -d' ' -f1,3,5,7 | awk -v d=$maxdist '($1==$3)&&(($2-$4<=d)||($2-$4>=d))' >! $outdir/filtered.txt

# Split by chromosome
echo "Splitting by chromosome..." | scripts-send2err
(cd $outdir; awk -F' ' '{print>$1}' filtered.txt)

# Analyze one chromosome at a time
set CHR = `cat $genome_dir/genome.bed | cut -f1`
foreach chr ($CHR)
  set outmat = $outdir/matrix.$chr.mtx
  echo "Storing chromosome $chr at 100bp resolution..." | scripts-send2err

  # Obtain matrix size (in 100bp resolution; 100bp is hardcoded)
  set n = `cat $genome_dir/genome.bed | awk -v c=$chr '{if ($1==c) print $3+100}' | sed 's/..$//'`
  
  # Obtain matrix data
  cat $outdir/$chr | cut -d' ' -f2,4 | awk '($1>100)&&($2>100)' | sed 's/.. / /' | sed 's/..$//' | awk -v n=$n '($1<=n)&&($2<=n)' | sort | uniq -c | sed 's/^ *//' >! $outmat.out
  set N = `cat $outmat.out | wc -l`

  # Generate sparse matrices
  echo '%%MatrixMarket matrix coordinate integer general' >! $outmat
  echo $n $n $N >> $outmat
  cat $outmat.out | awk '{print $2,$3,$1}' >> $outmat

  # Clean up
  rm -f $outdir/$chr $outmat.out
end

# Calculate statistics
set stats = `echo $objects | tr ' ' '\n' | awk -v d=$branch '{print d"/"$0"/stats.tsv"}'`
cat $stats | cut -f-2 | sort | tools-mergeuniq -merge | tools-vectors sum -n 0 >! $outdir/stats.tsv

# Clean up
rm -f $outdir/filtered.txt

# -------------------------------------
# -----  MAIN CODE ABOVE --------------
# -------------------------------------

# save variables
source ./code/code.main/scripts-save-job-vars

# done
scripts-send2err "Done."


