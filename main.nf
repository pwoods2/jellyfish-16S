#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Define Parameters
//params.input_dir = "data-use"
//params.output_dir = "results2"
//params.database = "emu_db_silva"
//params.threads_pc = 4
//params.threads_emu = 15

// Phase 1: Porechop Adapter Trimming

process porechopTrimming {
    tag "$filename"
    publishDir "${params.output_dir}/porechop", mode: 'copy'

    input:
    tuple val(filename), path(reads)

    output:
    tuple val(filename), path("${filename}.porechop.fastq.gz"), emit: trimmed_reads

    script:
    """
    porechop -i $reads -o ${filename}.porechop.fastq.gz --threads ${params.threads_pc}
    """
}

// Phase 2: Chopper Quality Filtering

process chopperFiltering {
    tag "$filename"
    publishDir "${params.output_dir}/chopper", mode: 'copy'

    input:
    tuple val(filename), path(reads)

    output:
    tuple val(filename), path("${filename}_trimmed.fastq"), emit: filtered_reads

    script:
    """
    gunzip -c $reads | chopper -q 20 > ${filename}_trimmed.fastq
    """
}

// Phase 3: Emu Abundance
 
process emuAbundance {
    tag "$filename"
    publishDir "${params.output_dir}/emu", mode: 'copy'
    
    // Note: ensure emu installed on machine to use 
    input:
    tuple val(filename), path(reads)
    path db

    output:
    path "${filename}*", emit: emu_results

    script:
    """
    emu abundance $reads \
        --db $db \
        --type map-ont \
        --threads ${params.threads_emu} \
        --output-dir . \
        --output-basename ${filename} \
        --keep-counts
    """
}

workflow {
    // 1. Prepare input file information
    read_ch = Channel
        .fromPath(params.input_dir)
        .map { file -> 
            // file.name gets the string "sample.R1.fastq.gz"
            // .tokenize('.') splits it by dots into a list: [sample, R1, fastq, gz]
            // [0] takes the very first item
            def filename = file.name.tokenize('.')[0]
            return tuple(filename, file) 
        }

    // 2. Connect all processes
    porechopTrimming(read_ch)
    chopperFiltering(porechopTrimming.out.trimmed_reads)
    
    // Using params.emu_db (standardized from your previous JSON key)
    emuAbundance(chopperFiltering.out.filtered_reads, file(params.database))
}