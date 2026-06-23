#!/usr/bin/env nextflow
nextflow.enable.dsl=2

params.sra_samples  = channel.of('SRR34052411', 'SRR34052351', 'SRR34052352')
params.outdir = 's3://nextflow-test-run/results'

process SRADOWNLOAD {
    container 'ncbi/sra-tools'
    publishDir "${params.outdir}/fastqc", mode: 'copy'
    
    input:
    val sra_sample
    
    output:
    path "${sra_sample}.sra", emit: sra
    path "${sra_sample}.fastq", emit: fastq
    
    script:
    """
    echo "Running FASTQC on ${sra_sample}"
    prefetch ${sra_sample} | fasterq-dump
    echo "Download completed for ${sra_sample}"
    """
}

process SALMON {
    container 'community.wave.seqera.io/library/salmon:1.10.3--dc33937abc5bffd1'
    publishDir "${params.outdir}/salmon_output", mode: 'copy'
    
    input:
    path fastq_sample
    
    output:
    path "${fastq_sample}-quant.sf"
    
    script:
    """
    echo "Downloading transcriptome .fa file to index"
    aws s3 sync s3://ngi-igenomes/igenomes/Homo_sapiens/NCBI/GRCh38/Sequence/transcriptome/ ./human_transcripts/ --no-sign-request
    echo "Indexing transcriptome"
    salmon index -t ./human_transcripts/transcripts.fa -i ./human_transcripts
    echo "Running salmon"
    salmon quant -i transcripts_index -l A \
     -r ${fastq_sample} \
     -p 8 -g annotation.gtf -o quants/sample_quant

    """
}

workflow {
    fastq_files = SRADOWNLOAD(params.sra_samples)
    SALMON(fastq_files.fastq)
}