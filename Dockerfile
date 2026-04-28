# Dockerfile for Nextflow RNA-seq QC + trimming demo
# Tools: FastQC, fastp, MultiQC
# Base: micromamba (lightweight conda-forge/bioconda installer)

FROM mambaorg/micromamba:1.5.8

LABEL description="QC + trimming tools for Nextflow teaching demo"
LABEL maintainer="your-name@example.com"

# Install all three tools in a single conda environment.
# Versions are pinned so the demo is reproducible across re-builds.
USER root
RUN micromamba install -n base -y -c conda-forge -c bioconda \
        fastqc=0.12.1 \
        fastp=0.23.4 \
        multiqc=1.21 \
        procps-ng \
    && micromamba clean --all --yes

# Make conda env binaries available to non-login shells (Nextflow runs commands
# via `bash -c`, which doesn't source ~/.bashrc, so PATH must be set explicitly).
ENV PATH=/opt/conda/bin:$PATH

# Quick sanity check at build time — fails the build if any tool is broken.
RUN fastqc --version && fastp --version && multiqc --version

# Default to bash so `docker run -it ... bash` drops into a usable shell.
CMD ["/bin/bash"]
