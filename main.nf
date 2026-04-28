#!/usr/bin/env nextflow

/*
 * ============================================================================
 *  RNA-seq QC + Trimming Demo Pipeline
 * ============================================================================
 *
 *  A minimal teaching pipeline that demonstrates core Nextflow DSL2 concepts:
 *    - Channels and channel factories
 *    - Processes with tuple inputs/outputs
 *    - Implicit parallelism across samples
 *    - Channel operators (collect)
 *    - The workflow block that wires processes together
 *    - Container-based execution for reproducibility
 *
 *  Pipeline steps:
 *    1. FASTQC_RAW : Quality control on the raw FASTQ pairs
 *    2. FASTP      : Adapter + quality trimming, produces its own QC report
 *    3. MULTIQC    : Aggregates all the above into a single HTML report
 *
 *  Run with:
 *    nextflow run main.nf
 *
 *  Run with custom inputs:
 *    nextflow run main.nf --reads 'data/*_{1,2}.fastq.gz' --outdir my_results
 * ============================================================================
 */


/*
 * ----------------------------------------------------------------------------
 *  PIPELINE PARAMETERS
 * ----------------------------------------------------------------------------
 *  Anything declared under `params` can be overridden from the command line
 *  using `--paramName value`. This is Nextflow's convention for user-facing
 *  knobs. The values below are sensible defaults for the demo.
 *
 *  TEACHING NOTE: Compare `--reads` (a pipeline parameter, double dash) with
 *  `-resume` (a Nextflow runtime flag, single dash). Students mix these up
 *  constantly. Single dash = Nextflow itself, double dash = your pipeline.
 * ----------------------------------------------------------------------------
 */
params.reads  = "${projectDir}/data/*_{1,2}.fastq.gz"  // glob pattern for paired reads
params.outdir = "${projectDir}/results"                 // where final outputs land

// Print a small banner at startup so students see their parameters at a glance.
log.info """
    ============================================
     RNA-seq QC + Trimming Demo
    ============================================
     reads  : ${params.reads}
     outdir : ${params.outdir}
    ============================================
    """.stripIndent()


/*
 * ============================================================================
 *  PROCESS DEFINITIONS
 * ============================================================================
 *  A `process` is a unit of work — typically a single tool invocation. Each
 *  process is isolated: it runs in its own working directory, with only the
 *  files declared as inputs available to it. This isolation is what makes
 *  Nextflow pipelines reproducible and parallelizable.
 *
 *  Anatomy of a process:
 *      process NAME {
 *          tag         <-- a label shown in the run log per task
 *          publishDir  <-- where to copy/symlink outputs after success
 *          input:      <-- what this process needs to start
 *          output:     <-- what files this process promises to produce
 *          script:     <-- the actual shell commands
 *      }
 * ============================================================================
 */


/*
 * ----------------------------------------------------------------------------
 *  PROCESS 1: FASTQC on raw reads
 * ----------------------------------------------------------------------------
 *  Runs FastQC on each pair of raw FASTQ files. FastQC produces an HTML
 *  report and a zip archive per input file, both of which MultiQC can parse.
 * ----------------------------------------------------------------------------
 */
process FASTQC_RAW {

    // `tag` adds a per-task label to the Nextflow log. Without it, you just
    // see "FASTQC_RAW (1)", "FASTQC_RAW (2)" etc. With it, you see the
    // actual sample IDs — much friendlier when debugging.
    tag "${sample_id}"

    // `publishDir` tells Nextflow to copy outputs out of the hidden work/
    // directory into a human-readable location after the task succeeds.
    // mode 'copy' makes a real copy (vs 'symlink', the default, which is
    // faster but breaks if you delete the work/ directory).
    publishDir "${params.outdir}/fastqc_raw", mode: 'copy'

    // The container directive says "run this process inside this Docker
    // image". This overrides any global container from nextflow.config.
    // Here we use the same image for all processes, but in real pipelines
    // each process often has its own purpose-built container.
    container 'nf-rnaseq-demo:0.1'

    input:
    // A tuple input means "I expect a sample ID alongside its files".
    // The `path(reads)` part will be a list of two files (R1, R2) because
    // that's how Channel.fromFilePairs emits them. Nextflow stages these
    // files into the working directory automatically.
    tuple val(sample_id), path(reads)

    output:
    // We declare every file we want Nextflow to track. The glob *_fastqc.*
    // captures both the .html and .zip outputs FastQC produces.
    // `emit: reports` names this output channel so the workflow block can
    // reference it as FASTQC_RAW.out.reports.
    path "*_fastqc.{html,zip}", emit: reports

    script:
    // Triple-quoted string = the shell script that actually runs.
    // Variables in ${...} are interpolated by Nextflow BEFORE the script
    // runs (Groovy substitution). If you need a literal shell variable,
    // escape the dollar sign as \$VAR.
    """
    echo "Running FastQC on sample: ${sample_id}"
    fastqc --quiet --threads ${task.cpus ?: 2} ${reads}
    """
}


/*
 * ----------------------------------------------------------------------------
 *  PROCESS 2: fastp adapter + quality trimming
 * ----------------------------------------------------------------------------
 *  fastp does adapter detection, quality trimming, and produces its own QC
 *  report (JSON for MultiQC, HTML for human eyes) all in one pass. It's
 *  faster than the older FastQC + Trim Galore + cutadapt combination.
 * ----------------------------------------------------------------------------
 */
process FASTP {

    tag "${sample_id}"
    publishDir "${params.outdir}/fastp", mode: 'copy'
    container 'nf-rnaseq-demo:0.1'

    input:
    tuple val(sample_id), path(reads)

    output:
    // Multiple named output channels — the workflow can reference each one
    // independently. The trimmed reads continue to downstream steps (none
    // in this demo, but in a real pipeline they'd feed an aligner). The
    // JSON and HTML are picked up by MultiQC.
    tuple val(sample_id), path("${sample_id}_trimmed_{1,2}.fastq.gz"), emit: trimmed_reads
    path "${sample_id}.fastp.json",                                     emit: json
    path "${sample_id}.fastp.html",                                     emit: html

    script:
    """
    echo "Running fastp on sample: ${sample_id}"
    fastp \\
        --in1  ${reads[0]} \\
        --in2  ${reads[1]} \\
        --out1 ${sample_id}_trimmed_1.fastq.gz \\
        --out2 ${sample_id}_trimmed_2.fastq.gz \\
        --json ${sample_id}.fastp.json \\
        --html ${sample_id}.fastp.html \\
        --thread ${task.cpus ?: 2} \\
        2> ${sample_id}.fastp.log
    """
}


/*
 * ----------------------------------------------------------------------------
 *  PROCESS 3: MultiQC aggregate report
 * ----------------------------------------------------------------------------
 *  MultiQC scans a directory for known report formats from many tools and
 *  produces one combined HTML summary. Here we feed it all the FastQC zips
 *  and fastp JSONs at once.
 * ----------------------------------------------------------------------------
 */
process MULTIQC {

    // No `tag` here because MultiQC runs only once for the whole run, not
    // once per sample. The default label is fine.
    publishDir "${params.outdir}/multiqc", mode: 'copy'
    container 'nf-rnaseq-demo:0.1'

    input:
    // `path '*'` stages every file in the input channel into the work dir
    // with its original name. We don't need a sample ID here because
    // MultiQC processes everything together.
    path '*'

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data",        emit: data

    script:
    """
    multiqc . --force
    """
}


/*
 * ============================================================================
 *  WORKFLOW BLOCK
 * ============================================================================
 *  This is where the pipeline actually comes together. Processes above are
 *  just definitions — they don't run until the workflow block calls them
 *  and connects their channels.
 *
 *  The workflow uses CHANNELS to pass data between processes. A channel is
 *  an asynchronous queue: when a value arrives, any process consuming that
 *  channel gets a new task. This is why Nextflow can run all three samples
 *  through FastQC simultaneously without any explicit loop.
 * ============================================================================
 */
workflow {

    /*
     * ------------------------------------------------------------------------
     *  Step 1: Build the input channel of paired reads
     * ------------------------------------------------------------------------
     *  Channel.fromFilePairs is a magic factory that finds files matching
     *  a glob, groups them by their shared prefix, and emits each pair as
     *  a tuple [sample_id, [read1, read2]].
     *
     *  Glob pattern:  data/*_{1,2}.fastq.gz
     *  The {1,2} brace expansion tells Nextflow which part of the filename
     *  varies between mates of a pair. Everything before the underscore
     *  becomes the sample ID.
     *
     *  So  data/SRR6357070_1.fastq.gz  +  data/SRR6357070_2.fastq.gz
     *  becomes:  ["SRR6357070", [SRR6357070_1.fastq.gz, SRR6357070_2.fastq.gz]]
     *
     *  `checkIfExists: true` makes Nextflow fail fast with a clear error
     *  message if the glob matches nothing — far better than mysterious
     *  "channel is empty" errors halfway through the run.
     * ------------------------------------------------------------------------
     */
    read_pairs_ch = Channel.fromFilePairs(params.reads, checkIfExists: true)

    // .view() prints whatever is in the channel — invaluable for debugging.
    // Comment this out for production runs.
    read_pairs_ch.view { sample_id, reads -> "Found sample: ${sample_id}" }


    /*
     * ------------------------------------------------------------------------
     *  Step 2: Run FastQC on raw reads (in parallel across samples)
     * ------------------------------------------------------------------------
     *  Calling FASTQC_RAW(read_pairs_ch) submits one task per item in the
     *  channel. With three samples in the channel, three tasks are queued
     *  and Nextflow runs them concurrently (subject to executor limits).
     *
     *  The output is accessed via FASTQC_RAW.out.<emit_name>.
     * ------------------------------------------------------------------------
     */
    FASTQC_RAW(read_pairs_ch)


    /*
     * ------------------------------------------------------------------------
     *  Step 3: Run fastp on the same raw reads (also in parallel)
     * ------------------------------------------------------------------------
     *  Notice we feed the SAME read_pairs_ch into FASTP. Channels in DSL2
     *  can be consumed multiple times — this is a change from the old DSL1
     *  behavior and is one of the most important practical improvements.
     *
     *  FASTQC_RAW and FASTP have no dependency on each other, so Nextflow
     *  is free to run them concurrently. With six samples worth of work
     *  (3 FastQC + 3 fastp), you'll see all six tasks scheduled at once.
     * ------------------------------------------------------------------------
     */
    FASTP(read_pairs_ch)


    /*
     * ------------------------------------------------------------------------
     *  Step 4: Collect every report into a single channel for MultiQC
     * ------------------------------------------------------------------------
     *  MultiQC needs ALL reports together in one task — it can't run
     *  per-sample. So we need to gather all the scattered reports back
     *  into a single emission.
     *
     *  Two operators are doing the work:
     *
     *    .mix()       Combines channels into one. Order is not guaranteed,
     *                 which is fine because MultiQC doesn't care.
     *
     *    .collect()   Gathers ALL items from a channel into a single list,
     *                 emitted as one chunk. This is what turns a stream of
     *                 N items into a single "here's everything" emission.
     *
     *  Without .collect(), MultiQC would run N times (once per file), which
     *  is wrong. This is THE classic Nextflow gotcha and worth dwelling on
     *  in the lesson.
     * ------------------------------------------------------------------------
     */
    multiqc_input_ch = FASTQC_RAW.out.reports
        .mix(FASTP.out.json)
        .mix(FASTP.out.html)
        .collect()


    /*
     * ------------------------------------------------------------------------
     *  Step 5: Run MultiQC on the aggregated reports
     * ------------------------------------------------------------------------
     */
    MULTIQC(multiqc_input_ch)
}


/*
 * ============================================================================
 *  COMPLETION HANDLER
 * ============================================================================
 *  Runs after the workflow finishes (success OR failure). Useful for a
 *  final summary message — students appreciate the closure.
 * ============================================================================
 */
workflow.onComplete {
    log.info """
        ============================================
         Pipeline complete
        ============================================
         Status   : ${workflow.success ? 'SUCCESS' : 'FAILED'}
         Duration : ${workflow.duration}
         Results  : ${params.outdir}
         Open     : ${params.outdir}/multiqc/multiqc_report.html
        ============================================
        """.stripIndent()
}
