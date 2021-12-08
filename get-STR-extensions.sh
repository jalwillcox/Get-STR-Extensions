#!/bin/bash

#SBATCH -J get-STR-extensions
#SBATCH -o %x.%j.log
#SBATCH -e %x.%j.err
#SBATCH -p short
#SBATCH -t 0-05:00:00
#SBATCH -n 1
#SBATCH -c 1
#SBATCH --mem=1G
##SBATCH --dependency=singleton

echo $0 $@

### USAGE

print_usage() {
  printf "

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 GET STR EXTENSIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

 This script is intended to use aligned paired-end reads to identify
  the presence of STRs that have extended beyond the length of a single
  read.

 -------------------
 Required Programs
 -------------------

 This script uses the following programs:

  samtools/1.3.1
  bedtools/2.27.1

 -------------------
 Flags
 -------------------

 -b (arg, required)	an alignment file (bam or cram) of paired-end reads.
 -g (arg, required)	the genome fasta that matches the bam/cram file
 -o (arg, required)	the basename for output
 -r (arg, required)     the region that includes the STR - make sure to include (~100bp) some flanking unique sequence
 -s (arg, required)	the repeated sequence

 -l (arg)		the length of a read (default: 150)
 -t (arg)		number of threads to use

 -h			print usage

 -------------------
 Example Usage
 -------------------

 get-STR-extensions.sh -b sample1.bam -g ./Homo_sapiens_assembly38.fasta -s CTT -r chr9:69037185-69037404 -o sample1-CTT

 -------------------
 Output
 -------------------

 *fq			A fastq file with all identified reads for the STR region 
 *_repeats.txt		A table of repeat lengths and read counts by length
 *_terminalSeq.txt	A list of STRs by read with the flanking sequences

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~



"
}

### Get Arguments

bam=''
genome=''
outname=''
region=''
seq=''
threads=1
rl=150

while getopts 'b:g:o:r:s:t:l:h' flag; do
  case "${flag}" in
    b) bam="${OPTARG}" ;;
    g) genome="${OPTARG}" ;;
    o) outname="${OPTARG}" ;;
    r) region="${OPTARG}" ;;
    s) seq="${OPTARG}" ;;
    l) rl="${OPTARG}" ;;
    t) threads="${OPTARG}" ;;
    h) print_usage ; exit ;;
    *) print_usage
       exit 1 ;;
  esac
done

if [ -z "$bam" ]; then
  print_usage
  echo "ERROR: -b argument missing, please enter a bam or cram file"
  exit 1
elif [ -z "$genome" ]; then
  print_usage
  echo "ERROR: -g argument missing, please enter a genome"
  exit 1
elif [ -z "$outname" ]; then
  print_usage
  echo "ERROR: -o argument missing, please enter an ouptut filename"
  exit 1
elif [ -z "$region" ]; then
  print_usage
  echo "ERROR: -r argument missing, please enter a region of the STR"
  exit 1
elif [ -z "$seq" ]; then
  print_usage
  echo "ERROR: -s argument missing, please enter the repeat sequence"
  exit 1
fi

rs=$(revcomp $seq) 

outdir=${outname}-out
mkdir ${outdir}

### Define Functions

revcomp(){
  echo $1 | rev | sed "s/T/B/g" | sed "s/A/T/g" | sed "s/B/A/g" | sed "s/G/B/g" | sed "s/C/G/g" | sed "s/B/C/g"
}


### Retrieve reads for STR

outbam=${outdir}/${outname}.bam
outsam=${outdir}/${outname}.sam
readnames=${outdir}/${outname}-readnames.txt

samtools view -bh -T $genome $bam $region > $outbam
samtools view $outbam | cut -f1 | sed 's/^/\^&/g' > $readnames
samtools view -H $bam > $outsam
samtools view -@$threads -T $genome $bam | grep -w -f $readnames >> $outsam

rm $outbam $readnames

samtools sort $outsam > $outbam
samtools index $outbam
fq=${outdir}/${outname}.fq
bedtools bamtofastq -i $outbam -fq $fq

rm ${outbam}* $outsam

sed "s/$seq\|$(revcomp $seq)/X/g" $fq | grep -o "X*" | sed "s/X/$seq/g" | sort | uniq -c | while read i j ; do echo -e "$i\t$(printf $j | wc -c)\t$j" ; done | sed "1 i count\trepeat_length\trepeat" > ${outdir}/${outname}_repeats.txt

echo "__Terminal-1__" > ${outdir}/${outname}_terminalSeq.txt
cat <(grep -o "${seq}${seq}${seq}.*" $fq) <(grep -o ".*${rs}${rs}${rs}" $fq | while read i ; do revcomp $i ; done) | sort >> ${outdir}/${outname}_terminalSeq.txt
echo "__Terminal-2__" >> ${outdir}/${outname}_terminalSeq.txt
cat <(grep -o "${rs}${rs}${rs}.*" $fq) <(grep -o ".*${seq}${seq}${seq}" $fq | while read i ; do revcomp $i ; done) | sort >> ${outdir}/${outname}_terminalSeq.txt







