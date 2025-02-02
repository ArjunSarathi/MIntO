#!/usr/bin/env python

'''
Binning preparation of contigs from assembly/coassembly.

Authors: Carmen Saenz, Mani Arumugam
'''

import snakemake

include: '../scripts/07-common-rules.smk'
include: '../scripts/08-common-rules.smk'

localrules: filter_contigs_illumina_single, filter_contigs_illumina_coas, \
            filter_contigs_nanopore, filter_contigs_illumina_single_nanopore, \
            check_depth_batches, combine_contigs_depth_batches, combine_fasta_batches, \
            combine_fasta, check_depths, combine_depth

#
# configuration yaml file
# import sys
from os import path
import math

# args = sys.argv
# config_path = args[args.index("--configfile") + 1]
config_path = 'configuration yaml file' #args[args_idx+1]
print(" *******************************")
print(" Reading configuration yaml file")#: , config_path)
print(" *******************************")
print("  ")

# Variables from configuration yaml file

# some variables
if config['PROJECT'] is None:
    print('ERROR in ', config_path, ': PROJECT variable is empty. Please, complete ', config_path)
else:
    project_name = config['PROJECT']

if config['working_dir'] is None:
    print('ERROR in ', config_path, ': working_dir variable is empty. Please, complete ', config_path)
elif path.exists(config['working_dir']) is False:
    print('ERROR in ', config_path, ': working_dir variable path does not exit. Please, complete ', config_path)
else:
    working_dir = config['working_dir']

if config['local_dir'] is None:
    prints('ERROR in ', config_path, ': local_dir variable is empty. Please, complete ', config_path)
else:
    local_dir = config['local_dir']

if config['minto_dir'] is None:
    print('ERROR in ', config_path, ': minto_dir variable in configuration yaml file is empty. Please, complete ', config_path)
elif path.exists(config['minto_dir']) is False:
    print('ERROR in ', config_path, ': minto_dir variable path does not exit. Please, complete ', config_path)
else:
    minto_dir=config["minto_dir"]
    script_dir=config["minto_dir"]+"/scripts/"

if config['METADATA'] is None:
    print('WARNING in ', config_path, ': METADATA variable is empty. Samples will be analyzed excluding the metadata.')
    metadata=config["METADATA"]
elif config['METADATA'] == "None":
    print('WARNING in ', config_path, ': METADATA variable is empty. Samples will be analyzed excluding the metadata.')
    metadata=config["METADATA"]
elif path.exists(config['METADATA']) is False:
    print('ERROR in ', config_path, ': METADATA variable path does not exit. Please, complete ', config_path)
else:
    metadata=config["METADATA"]

if config['MIN_FASTA_LENGTH'] is None:
    print('ERROR in ', config_path, ': MIN_FASTA_LENGTH variable is empty. Please, complete ', config_path)
elif type(config['MIN_FASTA_LENGTH']) != int:
    print('ERROR in ', config_path, ': MIN_FASTA_LENGTH variable is not an integer. Please, complete ', config_path)

# Scaffold type
SCAFFOLDS_type = list()
# Make list of illumina samples, if ILLUMINA in config
ilmn_samples = list()
if 'ILLUMINA' in config:
    if config['ILLUMINA'] is None:
        print('ERROR in ', config_path, ': ILLUMINA list of samples is empty. Please, complete ', config_path)
    else:
        SCAFFOLDS_type.append('illumina_single')
        #print("Samples:")
        for ilmn in config["ILLUMINA"]:
            #print(" "+ilmn)
            ilmn_samples.append(ilmn)
else:
    print('WARNING in ', config_path, ': ILLUMINA list of samples is empty. Skipping short-reads assembly.')

if type(config['METASPADES_hybrid_max_k']) != int or config['METASPADES_hybrid_max_k']%2==0:
    print('ERROR in ', config_path, ': METASPADES_hybrid_max_k variable must be an odd integer')
elif 'METASPADES_custom_build' in config:
    if config['METASPADES_hybrid_max_k'] < 300:
        hybrid_max_k = config['METASPADES_hybrid_max_k']
    else:
        print('ERROR in ', config_path, ': METASPADES_hybrid_max_k variable must be below 300.')
else:
    if config['METASPADES_hybrid_max_k'] < 128:
        hybrid_max_k = config['METASPADES_hybrid_max_k']
    else:
        print('ERROR in ', config_path, ': METASPADES_hybrid_max_k variable must be below 128.')

if type(config['METASPADES_illumina_max_k']) != int or config['METASPADES_illumina_max_k']%2==0:
    print('ERROR in ', config_path, ': METASPADES_illumina_max_k variable must be an odd integer')
elif 'METASPADES_custom_build' in config:
    if config['METASPADES_illumina_max_k'] < 300:
        illumina_max_k = config['METASPADES_illumina_max_k']
    else:
        print('ERROR in ', config_path, ': METASPADES_illumina_max_k variable must be below 300.')
else:
    if config['METASPADES_illumina_max_k'] < 128:
        illumina_max_k = config['METASPADES_illumina_max_k']
    else:
        print('ERROR in ', config_path, ': METASPADES_illumina_max_k variable must be below 128.')

batch_size = 100
if config['CONTIG_MAPPING_BATCH_SIZE'] is None:
    print('ERROR in ', config_path, ': CONTIG_MAPPING_BATCH_SIZE variable is empty. Please, complete ', config_path)
elif type(config['CONTIG_MAPPING_BATCH_SIZE']) != int:
    print('ERROR in ', config_path, ': CONTIG_MAPPING_BATCH_SIZE variable is not an integer. Please, complete ', config_path)
else:
    batch_size = config['CONTIG_MAPPING_BATCH_SIZE']

spades_contigs_or_scaffolds = "scaffolds"
if config['SPADES_CONTIGS_OR_SCAFFOLDS'] in ('contigs', 'contig', 'scaffolds', 'scaffold'):
    spades_contigs_or_scaffolds = config['SPADES_CONTIGS_OR_SCAFFOLDS']

if config['BWA_threads'] is None:
    print('ERROR in ', config_path, ': BWA_threads variable is empty. Please, complete ', config_path)
elif type(config['BWA_threads']) != int:
    print('ERROR in ', config_path, ': BWA_threads variable is not an integer. Please, complete ', config_path)

if config['BWA_memory'] is None:
    print('ERROR in ', config_path, ': BWA_memory variable is empty. Please, complete ', config_path)
elif type(config['BWA_memory']) != int:
    print('ERROR in ', config_path, ': BWA_memory variable is not an integer. Please, complete ', config_path)

if config['SAMTOOLS_sort_threads'] is None:
    print('ERROR in ', config_path, ': SAMTOOLS_sort_threads variable is empty. Please, complete ', config_path)
elif type(config['SAMTOOLS_sort_threads']) != int:
    print('ERROR in ', config_path, ': SAMTOOLS_sort_threads variable is not an integer. Please, complete ', config_path)

if config['SAMTOOLS_sort_perthread_memgb'] is None:
    print('ERROR in ', config_path, ': SAMTOOLS_sort_perthread_memgb variable is empty. Please, complete ', config_path)
elif type(config['SAMTOOLS_sort_perthread_memgb']) != int:
    print('ERROR in ', config_path, ': SAMTOOLS_sort_perthread_memgb variable is not an integer. Please, complete ', config_path)

# Make list of nanopore assemblies, if NANOPORE in config
nanopore_assemblies = list()
if 'NANOPORE' in config:
    if config['NANOPORE'] is None:
        print('ERRROR in ', config_path, ': NANOPORE list of samples is empty. Please, complete ', config_path)
    else:
        #print("Nanopore assemblies:")
        SCAFFOLDS_type.append('nanopore')
        for nano in config["NANOPORE"]:
            #print(" "+nano)
            nanopore_assemblies.append(nano)
else:
    print('WARNING in ', config_path, ': NANOPORE list of samples is empty. Skipping long-reads assembly.')

# Make list of nanopore-illumina hybrid assemblies, if HYBRID in config
hybrid_assemblies = list()
if 'HYBRID' in config:
    if config['HYBRID'] is None:
        print('ERROR in ', config_path, ': HYBRID list of samples is empty. Please, complete ', config_path)
    else:
        #print("Hybrid assemblies:")
        SCAFFOLDS_type.append('illumina_single_nanopore')
        for nano in config["HYBRID"]:
            for ilmn in config["HYBRID"][nano].split("+"):
                #print(" "+nano+"-"+ilmn)
                hybrid_assemblies.append(nano+"-"+ilmn)
else:
    print('WARNING in ', config_path, ': HYBRID list of samples is empty. Skipping hybrid assembly.')

# Make list of illumina coassemblies, if COASSEMBLY in config
co_assemblies = list()
if 'COASSEMBLY' in config:
    if config['COASSEMBLY'] is None:
        print('ERROR in ', config_path, ': COASSEMBLY list of samples is empty. Please, complete ', config_path)
    else:
        #print("Coassemblies:")
        SCAFFOLDS_type.append('illumina_coas')
        for co in config["COASSEMBLY"]:
            #print(" "+co)
            co_assemblies.append(co)
else:
    print('WARNING in ', config_path, ': COASSEMBLY list of samples is empty. Skipping co-assembly.')


# Useful functions
def get_assemblies(scaffolds_type):
    if scaffolds_type == 'illumina_single_nanopore':
        return(hybrid_assemblies)
    elif scaffolds_type == 'nanopore':
        return(nanopore_assemblies)
    elif scaffolds_type == 'illumina_coas':
        return(co_assemblies)
    elif scaffolds_type == 'illumina_single':
        return(ilmn_samples)

def get_batch(assemblies, batch_no):
    start = (int(batch_no)-1)*batch_size
    end   = start + batch_size
    return(assemblies[start:end])


def get_num_batches(assemblies):
    batch_count = len(assemblies) / batch_size
    return(math.ceil(batch_count))

# Remove assembly types if specified

if 'EXCLUDE_ASSEMBLY_TYPES' in config:
    if config['EXCLUDE_ASSEMBLY_TYPES'] is not None:
        for item in config['EXCLUDE_ASSEMBLY_TYPES']:
            if item in SCAFFOLDS_type:
                SCAFFOLDS_type.remove(item)

# Define all the outputs needed by target 'all'

rule all:
    input:
        abundance = "{wd}/{omics}/8-1-binning/scaffolds.{min_seq_length}.abundance.npz".format(
                wd = working_dir,
                omics = config['omics'],
                min_seq_length = config['MIN_FASTA_LENGTH']),
        config_yaml = "{wd}/{omics}/mags_generation.yaml".format(
                wd = working_dir,
                omics = config['omics'])

###############################################################################################
# Filter contigs from
#  1. MetaSPAdes-individual-assembled illumina samples,
#  2. MEGAHIT-co-assembled illumina samples,
#  3. MetaSPAdes-hybrid-assembled illumina+nanopore data,
#  4. MetaFlye-assembled nanopore sequences
###############################################################################################

rule filter_contigs_nanopore:
    input:
        #lambda wildcards: expand("{wd}/{omics}/7-assembly/{sample}/{assembly_preset}/{sample}.assembly.polcirc.fasta",
        lambda wildcards: expand("{wd}/{omics}/7-assembly/{sample}/{assembly_preset}/{sample}.assembly.fasta",
                wd = wildcards.wd,
                omics = wildcards.omics,
                sample = get_batch(nanopore_assemblies, wildcards.batch),
                assembly_preset = config['METAFLYE_presets'])
    output:
        "{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta"
    wildcard_constraints:
        scaf_type = 'nanopore'
    resources:
        mem = 5
    params:
        min_length = lambda wildcards: wildcards.min_length
    run:
        filter_fasta_list_by_length(input, output[0], params.min_length)

rule filter_contigs_illumina_single_nanopore:
    input:
        #lambda wildcards: expand("{wd}/{omics}/7-assembly/{assembly}/{kmer_dir}/{assembly}.assembly.polcirc.fasta",
        lambda wildcards: expand("{wd}/{omics}/7-assembly/{assembly}/{kmer_dir}/{assembly}.{contig_or_scaffold}.fasta",
                wd = wildcards.wd,
                omics = wildcards.omics,
                assembly = get_batch(hybrid_assemblies, wildcards.batch),
                kmer_dir = "k21-" + str(hybrid_max_k),
                contig_or_scaffold = spades_contigs_or_scaffolds)
    output:
        "{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta"
    wildcard_constraints:
        scaf_type = 'illumina_single_nanopore'
    resources:
        mem = 5
    params:
        min_length = lambda wildcards: wildcards.min_length
    run:
        filter_fasta_list_by_length(input, output[0], params.min_length)

rule filter_contigs_illumina_single:
    input:
        lambda wildcards: expand("{wd}/{omics}/7-assembly/{illumina}/{kmer_dir}/{illumina}.{contig_or_scaffold}.fasta",
                wd = wildcards.wd,
                omics = wildcards.omics,
                illumina = get_batch(ilmn_samples, wildcards.batch),
                kmer_dir = "k21-" + str(hybrid_max_k),
                contig_or_scaffold = spades_contigs_or_scaffolds)
    output:
        "{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta"
        #"{wd}/{omics}/8-1-binning/{project}_scaffolds_{scaf_type}.{min_length}.fasta"
    wildcard_constraints:
        scaf_type = 'illumina_single'
    resources:
        mem = 5
    params:
        min_length = lambda wildcards: wildcards.min_length
    run:
        filter_fasta_list_by_length(input, output[0], params.min_length)

rule filter_contigs_illumina_coas:
    input:
        lambda wildcards: expand("{wd}/{omics}/7-assembly/{coassembly}/{assembly_preset}/{coassembly}.contigs.fasta",
                wd = wildcards.wd,
                omics = wildcards.omics,
                coassembly = get_batch(co_assemblies, wildcards.batch),
                assembly_preset = config['MEGAHIT_presets'])
    output:
        "{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta"
    wildcard_constraints:
        scaf_type = 'illumina_coas'
    resources:
        mem = 5
    params:
        min_length = lambda wildcards: wildcards.min_length
    run:
        filter_fasta_list_by_length(input, output[0], params.min_length)

################################################################################################
# Create BWA index for the filtered contigs
################################################################################################
rule BWA_index_contigs:
    input:
        scaffolds="{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta"
    output:
        bwaindex="{wd}/{omics}/6-mapping/BWA_index/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta.bwt.2bit.64"
    log:
        "{wd}/logs/{omics}/6-mapping/scaffolds_{scaf_type}/batch{batch}.{min_length}.BWA_index.log"
    params:
        local_loc = lambda wildcards: "{local_dir}/{omics}/6-mapping/BWA_index/scaffolds_{scaf_type}".format(local_dir=local_dir, omics=wildcards.omics, scaf_type=wildcards.scaf_type)
    resources:
        mem = 450
    threads: 4
    conda:
        config["minto_dir"]+"/envs/MIntO_base.yml" #bwa-mem2
    shell:
        """
        outdir=$(dirname {output})
        mkdir -p $outdir {params.local_loc}
        time (bwa-mem2 index {input.scaffolds} -p {params.local_loc}/$(basename {input})) >& {log}
        rsync -av {params.local_loc}/$(basename {input}).* $outdir/
        """

# Maps reads to contig-set using bwa2
# Baseline memory usage is:
#   Main: BWA_memory 25GB
#   Sort: using config values: SAMTOOLS_sort_threads and SAMTOOLS_sort_perthread_memgb;
#   E.g. 25GB for BWA, 2 sort threads and 10GB per-thread = 45GB
# If an attempt fails, 40GB extra for every new attempt, and this mostly affects non-sort processes.
# Once mapping succeeds, run coverM to get contig depth for this bam
rule map_contigs_BWA_depth_coverM:
    input:
        bwaindex=rules.BWA_index_contigs.output.bwaindex,
        fwd='{wd}/{omics}/6-corrected/{illumina}/{illumina}.1.fq.gz',
        rev='{wd}/{omics}/6-corrected/{illumina}/{illumina}.2.fq.gz'
    output:
        depth="{wd}/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}/{illumina}.{min_length}.depth.txt"
    params:
        map_threads = config['BWA_threads'],
        sort_threads = config['SAMTOOLS_sort_threads'],
        sort_mem = config['SAMTOOLS_sort_perthread_memgb'],
        local_loc = lambda wildcards: "{local_dir}/{omics}/6-mapping/{illumina}/{scaf_type}/{batch}/".format(local_dir=local_dir, omics=wildcards.omics, illumina=wildcards.illumina, scaf_type=wildcards.scaf_type, batch=wildcards.batch)
    log:
        "{wd}/logs/{omics}/6-mapping/{illumina}/{illumina}.scaffolds_{scaf_type}.batch{batch}.{min_length}.bwa2.log"
    resources:
        mem = lambda wildcards, attempt: config['BWA_memory'] + config['SAMTOOLS_sort_threads']*config['SAMTOOLS_sort_perthread_memgb'] + 40*(attempt-1)
    threads:
        config['BWA_threads']
    conda:
        config["minto_dir"]+"/envs/MIntO_base.yml" #bwa-mem2
    shell:
        """
        mkdir -p $(dirname {output}) {params.local_loc}
        local_file={params.local_loc}/$(basename {output.depth})
        db_name=$(echo {input.bwaindex} | sed "s/.bwt.2bit.64//")
        time (bwa-mem2 mem -P -a -t {params.map_threads} $db_name {input.fwd} {input.rev} \
                | msamtools filter -buS -p 95 -l 45 - \
                | samtools sort -m {params.sort_mem}G --threads {params.sort_threads} - \
                > $local_file.bam
              coverm contig --methods metabat --trim-min 10 --trim-max 90 --min-read-percent-identity 95 --threads {threads} --output-file $local_file.depth --bam-files $local_file.bam
              rsync -a $local_file.depth {output.depth}
        ) >& {log}
        rm $local_file.bam $local_file.depth
        """

# Combine coverM depths from individual samples
# I use python code passed from STDIN within "shell" so that I can use conda env.
rule contigs_depth_batch:
    input:
        depths = lambda wildcards: expand("{wd}/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}/{illumina}.{min_length}.depth.txt",
                                            wd = wildcards.wd,
                                            omics = wildcards.omics,
                                            scaf_type = wildcards.scaf_type,
                                            batch = wildcards.batch,
                                            min_length = wildcards.min_length,
                                            illumina=ilmn_samples)
    output:
        depths="{wd}/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}.{min_length}.depth.txt",
    resources:
        mem = 40
    threads:
        2
    log:
        "{wd}/logs/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}.{min_length}.depth.log"
    conda:
        config["minto_dir"]+"/envs/mags.yml" #pandas
    shell:
        """
python - {input.depths} << EOF > {output.depths}
import pandas as pd
import sys
df = pd.read_csv(sys.argv[1], header=0, sep = "\\t")
for filename in sys.argv[2:]:
    df2 = pd.read_csv(filename, header=0, sep = "\\t")
    df2 = df2.drop('totalAvgDepth', axis=1)
    df  = df.merge(df2, on=['contigName', 'contigLen'], how='inner')
df.to_csv(sys.stdout, sep = "\\t", index = False)
EOF
        """

##################################################
# Combining across batches within a scaffold_type
##################################################

# Sanity check to ensure that the order of sample-depths in the depth file is the same. Otherwise binning will be wrong!
rule check_depth_batches:
    input:
        depths = lambda wildcards: expand("{wd}/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}.{min_length}.depth.txt",
                                            wd = wildcards.wd,
                                            omics = wildcards.omics,
                                            scaf_type = wildcards.scaf_type,
                                            batch = list(range(1, 1+get_num_batches(get_assemblies(wildcards.scaf_type)))),
                                            min_length = wildcards.min_length)
    output:
        ok="{wd}/{omics}/8-1-binning/depth_{scaf_type}/batches.{min_length}.ok"
    shell:
        """
        rm --force {output}
        uniq_headers=$(for file in {input.depths}; do head -1 $file; done | sort -u | wc -l)
        if [ "$uniq_headers" == "1" ]; then
            touch {output}
        else
            # Headers were not unique. So report and set exit code for this rule to non-zero
            >&2 echo "Headers in depth files were not unique - please check depth files"
            test "1" == "2"
        fi
        """

rule combine_contigs_depth_batches:
    input:
        depths = lambda wildcards: expand("{wd}/{omics}/8-1-binning/depth_{scaf_type}/batch{batch}.{min_length}.depth.txt",
                                            wd = wildcards.wd,
                                            omics = wildcards.omics,
                                            scaf_type = wildcards.scaf_type,
                                            batch = list(range(1, 1+get_num_batches(get_assemblies(wildcards.scaf_type)))),
                                            min_length = wildcards.min_length),
        ok = rules.check_depth_batches.output.ok
    output:
        depths="{wd}/{omics}/8-1-binning/depth_{scaf_type}/combined.{min_length}.depth.txt",
    resources:
       mem = 10
    threads:
        1
    shell:
        """
        head -1 {input.depths[0]} > {output}
        (for file in {input.depths}; do tail -n +2 $file; done) >> {output}
        """


# Combine multiple fasta files from batches into one per scaf_type
rule combine_fasta_batches:
    input:
        fasta=lambda wildcards: expand("{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/batch{batch}.{min_length}.fasta",
                                            wd = wildcards.wd,
                                            omics = wildcards.omics,
                                            scaf_type = wildcards.scaf_type,
                                            batch = list(range(1, 1+get_num_batches(get_assemblies(wildcards.scaf_type)))),
                                            min_length = wildcards.min_length)
    output:
        fasta_combined="{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/combined.{min_length}.fasta"
    resources:
       mem = 10
    threads:
        1
    shell:
        """
        cat {input} > {output}
        """

#####################################
# Combining across scaffold_type
#####################################

# Combine multiple fasta files into one
rule combine_fasta:
    input:
        fasta=lambda wildcards: expand("{wd}/{omics}/8-1-binning/scaffolds_{scaf_type}/combined.{min_length}.fasta",
                wd = wildcards.wd,
                omics = wildcards.omics,
                min_length = wildcards.min_length,
                scaf_type = SCAFFOLDS_type)
    output:
        fasta_combined="{wd}/{omics}/8-1-binning/scaffolds.{min_length}.fasta"
    resources:
       mem = 10
    threads:
        1
    shell:
        """
        cat {input} > {output}
        """

# Sanity check to ensure that the order of sample-depths in the depth file is the same. Otherwise binning will be wrong!
rule check_depths:
    input:
        depths=lambda wildcards: expand("{wd}/{omics}/8-1-binning/depth_{scaf_type}/combined.{min_length}.depth.txt",
                wd = wildcards.wd,
                omics = wildcards.omics,
                min_length = wildcards.min_length,
                scaf_type = SCAFFOLDS_type)
    output:
        ok="{wd}/{omics}/8-1-binning/depths.{min_length}.ok"
    shell:
        """
        rm --force {output}
        uniq_headers=$(for file in {input.depths}; do head -1 $file; done | sort -u | wc -l)
        if [ "$uniq_headers" == "1" ]; then
            touch {output}
        else
            # Headers were not unique. So report and set exit code for this rule to non-zero
            >&2 echo "Headers in depth files were not unique - please check depth files"
            test "1" == "2"
        fi
        """

# Combine multiple depth files into one
rule combine_depth:
    input:
        depths=lambda wildcards: expand("{wd}/{omics}/8-1-binning/depth_{scaf_type}/combined.{min_length}.depth.txt",
                wd = wildcards.wd,
                omics = wildcards.omics,
                min_length = wildcards.min_length,
                scaf_type = SCAFFOLDS_type),
        depth_ok = rules.check_depths.output.ok
    output:
        depth_combined="{wd}/{omics}/8-1-binning/scaffolds.{min_length}.depth.txt"
    resources:
       mem = 10
    threads:
        1
    shell:
        """
        head -1 {input.depths[0]} > {output}
        (for file in {input.depths}; do tail -n +2 $file; done) >> {output}
        """

### Prepare abundance.npz for avamb v4+
rule make_abundance_npz:
    input:
        contigs_file = rules.combine_fasta.output.fasta_combined,
        depth_file = rules.combine_depth.output.depth_combined
    output:
        npz="{wd}/{omics}/8-1-binning/scaffolds.{min_length}.abundance.npz"
    log:
        "{wd}/logs/{omics}/8-1-binning/scaffolds.{min_length}.abundance.log"
    threads:
        1
    conda:
        config["minto_dir"]+"/envs/avamb.yml"
    shell:
        """
        time (python {script_dir}/make_vamb_abundance_npz.py --fasta {input.contigs_file} --jgi {input.depth_file} --output {output.npz} --samples {ilmn_samples}) >& {log}
        """

###############################################################################################
# Generate configuration yml file for recovery of MAGs and taxonomic annotation step - binning
###############################################################################################

rule config_yml_binning:
    output:
        config_file="{wd}/{omics}/mags_generation.yaml",
    resources:
        mem=2
    threads: 2
    log:
        "{wd}/logs/{omics}/config_yml_mags_generation.log"
    params:
        min_fasta_length=config['MIN_FASTA_LENGTH']
    shell:
        """
        time (echo "######################
# General settings
######################
PROJECT: {project_name}
working_dir: {wildcards.wd}
omics: {wildcards.omics}
local_dir: {local_dir}
minto_dir: {minto_dir}
METADATA: {metadata}

######################
# Program settings
######################
# COMMON PARAMETERS
#
MIN_FASTA_LENGTH: {params.min_fasta_length}
MIN_MAG_LENGTH: 500000
BINSPLIT_CHAR: _

# VAMB settings
#
BINNERS:
- aaey
- aaez
- vae384

VAMB_THREADS: 20
VAMB_memory: 40

# Use GPU in VAMB:
# could be "yes" or "no"
VAMB_GPU: no


# CHECKM settings
#
CHECKM_COMPLETENESS: 90  # higher than this
CHECKM_CONTAMINATION: 5  # lower than this
CHECKM_BATCH_SIZE: 50    # Process MAGs with this batch size
CHECKM_DATABASE: {minto_dir}/data/CheckM2_database/uniref100.KO.1.dmnd

# COVERM settings
#
COVERM_THREADS: 8
COVERM_memory: 5

# SCORING THE BEST GENOMES settings
#
# this could be checkm or genome
SCORE_METHOD: "checkm"

# MAG taxonomy settings
#
RUN_TAXONOMY: yes
TAXONOMY_NAME: phylophlan    # Currently, only phylophlan
TAXONOMY_CPUS: 8
TAXONOMY_memory: 5

# PHYLOPHLAN METAGENOMICS settings
#
TAXONOMY_DATABASE: SGB.Jan20
TAXONOMY_DATABASE_FOLDER: {minto_dir}/data" > {output.config_file}

) >& {log}
        """
