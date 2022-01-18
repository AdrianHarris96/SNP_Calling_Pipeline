#This is a script for SNP-calling.

#The -a, -b, -r, -f, and -o flags require read1 (<read1.fq>), read2 (<read2.fq>), the reference sequence (<ref.fa>), the location of the Mills file (</Location>), and the desired name for the output .bed file.

#Furthermore, you can perform the read realignment by invoking the optional -e flag.

#The optional -z flag will gunzip the output .vcf file.

#The optional -v flag allows the user to trace through the script in realtime.

#The optional -i flag will index the BAM file, following realignment.

#./snp_calling.sh -a <read1> -b <read2> -r <ref.fa> -f </path/to/Mills/Reference> -o <output_name.vcf>

#Mills Gold Standard > https://console.cloud.google.com/storage/browser/genomics-public-data/resources/broad/hg38/v0;tab=objects?prefix=&forceOnObjectsSortingFiltering=false