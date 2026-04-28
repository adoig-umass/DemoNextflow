# DemoNextflow
Document the nextflow programming language for the AI/Bioinformatics Journal Club

## Getting a linux environment to run the demo
If you have a mac, you should be set, they are unix/linux machanies already.

If you have windows,you will want to install the virtual machine for linux. First, reboot your computer, enter bios, and enable the following features.

"Inside the BIOS, the setting is usually in one of these locations and named one of these things:

On Intel CPUs: look for "Intel Virtualization Technology," "Intel VT-x," or "VT-x." Sometimes also "VT-d" (enable that too if present).
On AMD CPUs: look for "SVM Mode," "AMD-V," or "SVM."

The setting is typically under a tab called "Advanced," "CPU Configuration," "Security," or "System Configuration" — varies by vendor. Set it to Enabled, then save and exit (usually F10)."

Then enable the features...

"dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart"

Then reboot, go to the powershell and enter the following command to install the Windows Subsystem for Linux

"wsl --install"

Then reboot your computer and open the WSL using the command 

"wsl --set-default-version 2
wsl --install -d Ubuntu"

And you should now have a linux virtual machine on your windows PC!

## Docker instance to keep the environment stable and isolated
Use the dockerfile uploaded to the repository to build a container to run the demo. Copy the Dockerfile to the directory from which you will be working from.

Navigate to the directory you will be working in and use the command
 
  docker build -t nf-rnaseq-demo:0.1 .

This should take a few minutes, and then you can verify you have generated the container image by running a search of installed Docker images using 

  docker images | grep nf-rnaseq-demo

  Then, to verify that you have the installed the necessary software within the image, we are going to call docker to pump out the install versions in your image.

  docker run --rm nf-rnaseq-demo:0.1 fastqc --version
  docker run --rm nf-rnaseq-demo:0.1 fastp --version
  docker run --rm nf-rnaseq-demo:0.1 multiqc --version

  If the CLI spits out the version number, we are ready to download a test data sample.

  ## Download the test dataset from the nextflow repo
  Let's fetch some data using the download_test_data.sh shell script found in this repo.
  Copy the file to your directory. Run the script with

  bash download_test_data.sh

  This should download six sample data files.

  ## Using nextflow to process the data

  This nextflow pipeline will use the fastp tool for fastq file processing, including quality control metrics, adapter tripping, and quality filtering. Then FastQC will generate indicividual quality reports for each sample, and multiqc will combine them into a single readable report.

  We want to copy the actual nextflow script to our working directory to run this pipeline. Please download the main.nf file to the working directory.

  It will be useful to monitor the docker containers while the pipeline is running to demonstrate that the actual tools are being pulled from static images, and then launched in containers. To do this, open a new terminal window and enter 

  watch -n 0.5 'docker ps'

  We should now be able to run a docker containerized instance of the pipeline. In your CLI at the working directory, go ahead and enter the following command

  nextflow run main.nf

  
