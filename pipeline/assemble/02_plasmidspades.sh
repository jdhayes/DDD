#!/usr/bin/bash
#SBATCH -p intel,batch -N 1 -n 16 --mem 64gb --out logs/plasmidspades.%a.log -J plasmidspades

# Load modules
if [ -n "$MODULESHOME" ]; then
  module load spades/3.15.2
fi

# Define params
SAMPLES=samples_prefix.csv
INFOLDER=input
ASM=assembly

# Determine memory
MEM=$3
if [ ! $MEM ]; then
  MEM=16
fi

# Determine num CPUs
CPU=$SLURM_CPUS_ON_NODE
if [ -z $CPU ]; then
  CPU=$2
  if [ ! $CPU ]; then
    CPU=1
  fi
fi

# Determine job index
N=${SLURM_ARRAY_TASK_ID}
if [ ! $N ]; then
    N=$1
    if [ ! $N ]; then
        echo "Need an array id or cmdline val for the job"
        exit
    fi
fi

# Ensure parent output directory
mkdir -p $ASM

# Determine input data from job index
IFS=,
tail -n +2 $SAMPLES | sed -n ${N}p | while read SPECIES STRAIN JGILIBRARY BIOSAMPLE BIOPROJECT TAXONOMY_ID ORGANISM_NAME SRA_SAMPID SRA_RUNID LOCUSTAG TEMPLATE; do

  # Determine output directory
  STEM=$(echo -n $SPECIES | perl -p -e 's/\s+/_/g')
  OUTFOLDER=$ASM/${STEM}.plasmidspades
  echo "OUTPUT:\n\t${OUTFOLDER}"
  
  # Run spades with either --meta or --plasmid
  if [ -d $OUTFOLDER ]; then
    if [ ! -f $OUTFOLDER/scaffolds.fasta ]; then
        echo "Restarting spades.py --plasmid -o $OUTFOLDER"
        time spades.py --threads $CPU -m $MEM -o $OUTFOLDER --restart-from last
    fi
  else
      echo "Running spades.py --plasmid --threads $CPU -m $MEM -1 ${INFOLDER}/${STEM}_R1.fq.gz -2 ${INFOLDER}/${STEM}_R2.fq.gz -o $OUTFOLDER"
      time spades.py --plasmid --threads $CPU -m $MEM -1 ${INFOLDER}/${STEM}_R1.fq.gz -2 ${INFOLDER}/${STEM}_R2.fq.gz -o $OUTFOLDER
  fi

  # Clean up and compress
  if [ -f $OUTFOLDER/scaffolds.fasta ] && [ -f $OUTFOLDER/spades.log ]; then
    echo "Cleaning..."
    rm -rf $OUTFOLDER/before_rr.fasta $OUTFOLDER/corrected $OUTFOLDER/K*
    rm -rf $OUTFOLDER/assembly_graph_after_simplification.gfa $OUTFOLDER/tmp
    if [ -f $OUTFOLDER/contigs.fasta ]; then
      pigz $OUTFOLDER/contigs.fasta
      pigz $OUTFOLDER/spades.log
    fi
  fi
done
