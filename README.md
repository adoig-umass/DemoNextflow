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

Make a working directory by terminaling 

"mkdir Demo-nextflow"

## Install docker
Step 1: Open an Ubuntu session in WSL
Three ways to do this — pick whichever your students prefer:

From Start Menu: type "Ubuntu" and click the Ubuntu app
From Windows Terminal: open Windows Terminal, click the dropdown arrow next to the + tab, choose Ubuntu
From PowerShell or Command Prompt: type wsl and press Enter (drops you into your default WSL distro)

You should land at a prompt like andy@Cray:~$.
Step 2: Confirm WSL2 (not WSL1)
Docker Engine needs WSL2 because it requires a real Linux kernel. From PowerShell on Windows (not inside Ubuntu), run:
powershellwsl --list --verbose
The VERSION column should say 2. If it says 1, convert with:
powershellwsl --set-version Ubuntu 2
Step 3: Update Ubuntu and remove any old Docker packages
Inside Ubuntu:
bashsudo apt update
sudo apt upgrade -y
Then clear out any old or conflicting Docker packages that may have been installed before:
bashfor pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt remove -y $pkg 2>/dev/null
done
Don't worry if it reports nothing to remove — that just means the system was clean.
Step 4: Add Docker's official APT repository
This is the critical part — it's what gives you the up-to-date docker-ce package instead of Ubuntu's older docker.io package. Three sub-steps: install prerequisites, add Docker's GPG key, add the repo.
bash# Prerequisites for fetching the GPG key over HTTPS
sudo apt install -y ca-certificates curl

# Create the keyring directory
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker's signing key
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker's repo to APT's sources, pinned to your Ubuntu version
This is from a Claude interaction:

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Refresh the package index now that Docker's repo is included
sudo apt update
The $(. /etc/os-release && echo "$VERSION_CODENAME") expansion auto-detects your Ubuntu codename (e.g. noble for 24.04, jammy for 22.04). Worth pointing out to students — copy-pasting other people's commands often fails because they hardcode a different codename.
Step 5: Install Docker Engine
bashsudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
What each piece is:

docker-ce — the daemon (the actual container engine)
docker-ce-cli — the docker command-line client
containerd.io — the lower-level container runtime Docker uses under the hood
docker-buildx-plugin — modern image builder
docker-compose-plugin — docker compose subcommand for multi-container apps

Step 6: Start the Docker daemon
This is where WSL has a quirk worth knowing about. On a normal Ubuntu install, systemd would auto-start Docker. WSL's systemd support is opt-in and can be flaky. The most reliable approach in WSL is to start Docker manually:
bashsudo service docker start
You should see * Starting Docker: docker [ OK ].
To check it's running:
bashsudo service docker status

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

  
