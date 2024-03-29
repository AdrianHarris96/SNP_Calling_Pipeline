#! /bin/bash

realign=0
gunzip=0
v=0
index=0

while getopts "a:b:r:f:o:ezvih" option ;
do 
  case $option in
    a) read1=$OPTARG;;
    b) read2=$OPTARG;;
    r) ref=$OPTARG;;
    f) millsFile=$OPTARG;;
    o) output=$OPTARG;;
    e) realign=1;;
    z) gunzip=1;;
    v) v=1;;
    i) index=1;;
    h) echo "snp_calling usage: ./snp_calling.sh [-a] <read1.fq> [-b] <read2.fq> [-r] <ref.fa> [-f] <path_to_Mills_file> [-o] <output_name>."
      exit 0;;
    \?) echo "snp_calling usage: ./snp_calling.sh [-a] <read1.fq> [-b] <read2.fq> [-r] <ref.fa> [-f] <path_to_Mills_file> [-o] <output_name>."
      exit 1;;
  esac
done
#An alternative program exists using a -j flag to specify the path to java8. The user will receive a malformed error during realignment if the java8 is not in use. 
#Be sure that the reads, reference genome and GenomeAnalysisTK.jar are in the current working directory. 

if [ $v -eq 1 ]; then
  set -x
fi

#Increments through each senario of existence for read1 and read2 file. Exits if either or both do not exist.  
if test -f "$read1" && test -f "$read2"; then
  echo "Both read files exist."
elif test -f "$read1"; then
  echo "Read file 2 does not exists.";
  exit 
elif test -f "$read2"; then
  echo "Read file 1 does not exists.";
  exit 
else
  echo "Both read files do not exist.";
  exit 
fi

#Exits if reference genome does not exist.
if test -f "$ref"; then
  echo "The reference genome exists."
else 
  echo "The reference genome does not exists.";
  exit
fi

#Requesting input from the user on overwriting the VCF
if test -f "$output.vcf"; then
  echo -n "Would you like to overwrite $output.vcf? [Y/N]"; read answer
  case $answer in
    Y) echo "File will be overwritten.";;
    N) echo "Exiting."; 
    exit;;
    *) echo "Response not valid. Exiting."; 
    exit;;
  esac
fi

#Indexing of the reference sequence
bwa index $ref

#Mapping reads to the reference
bwa mem -R '@RG\tID:foo\tSM:bar\tLB:library1' $ref $read1 $read2 > lane.sam

#Conversion of sam file to bam file and sorting the created file
samtools view -Sb lane.sam | samtools sort -o lane_sorted.bam

#Indexing the reference again to form an .fai file. This must be done prior to running the improvement. 
samtools faidx $ref

#Must be created prior to running the realignment. Note: The .fa was stripped from the file by passing it to the chromosome variable and truncating the string. 
chromosome=$ref
chromosome=${chromosome::-3}
samtools dict $ref -o $chromosome.dict

#Indexing the sorted bam file. If this is not requested, the realignment (if requested) will occur in unsafe mode (-U).
if [ $index -eq 1 ];then 
  samtools index lane_sorted.bam
fi

#Print commands to terminal if requested
if [ $v -eq 1 ]; then
  set +x
fi

#This will either realign the indexed bam file or realign the raw bam file in unsafe mode. 
#The two GATK logs created for each step are concatenated to form one GATK log. 
#The other steps would like the user to check each lane for duplicates and merge the different lanes into library.bam. This library.bam will then be combined with other library.bam files to create a sample.bam file. With the current setup, we have only created 1 lane.bam, so going through the process of inputting into MarkDuplicates to output as a library to then be merged into a sample really does not make sense. 
if [ $realign -eq 1 ] && [ $index -eq 1 ]; then
  java -Xmx2g -jar GenomeAnalysisTK.jar -T RealignerTargetCreator -R $ref -I lane_sorted.bam -log GATK_1.log -o lane.intervals --known $millsFile; 
  java -Xmx4g -jar GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I lane_sorted.bam -log GATK_2.log -targetIntervals lane.intervals -known $millsFile -o lane_realigned.bam;
   cat GATK_1.log GATK_2.log > GATK.log
elif [ $realign -eq 1 ]; then
  java -Xmx2g -jar GenomeAnalysisTK.jar -T RealignerTargetCreator -R $ref -I lane_sorted.bam -U -log GATK_1.log -o lane.intervals --known $millsFile;
  java -Xmx4g -jar GenomeAnalysisTK.jar -T IndelRealigner -R $ref -I lane_sorted.bam -U -log GATK_2.log -targetIntervals lane.intervals -known $millsFile -o lane_realigned.bam; 
  cat GATK_1.log GATK_2.log > GATK.log
else 
  echo "Skip Realignment"
fi

if [ $v -eq 1 ]; then
  set -x
fi

#The code is made to converge to a single file here.
if [ $realign -eq 1 ] && [ $index -eq 1 ]; then
  samtools index lane_realigned.bam;
  cp lane_realigned.bam lane_final.bam
elif [ $realign -eq 1 ]; then
  #In the event of realigning without indexing 
  cp lane_realigned.bam lane_final.bam
else
  #In the event of no realigning and (indexing or no indexing) - lane_sorted.bam will exist in either case. 
  cp lane_sorted.bam lane_final.bam 
fi

bcftools mpileup -Ob -o $output_raw.bcf -f $ref lane_final.bam

#Creation of variant calling file (as a compressed file by default)
bcftools call -vmO z -o $output.vcf.gz $output_raw.bcf

#If gunzip is not a specified output by user, the default (z=0) will be to decompress the gz file. Otherwise, the final step will be to compress the vcf and remove the temporary vcf file, created simply for the format conversion to bed file.
if [ $gunzip -eq 1 ]; then 
  echo "$output.vcf.gz is ready."
else
  gzip -d $output.vcf.gz
  echo "$output.vcf is ready."
fi
