# Build:
# docker build --platform=linux/amd64 . -t docker-base-ml
# Push:
# docker tag docker-base-ml:latest ghcr.io/ankur-gupta/docker-base-ml:latest
# docker push ghcr.io/ankur-gupta/docker-base-ml:latest

FROM ubuntu:latest

# This is the user that will execute most of the commands within the docker container.
ARG ML_USER="neo"
ARG ML_USER_PASSWORD="agentsmith"

# Install the things that need root access first.
USER root

# To prevent interactive questions during `apt-get install`
ENV DEBIAN_FRONTEND=noninteractive

# We clean up apt cache to reduce image size as mentioned here:
# https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#run
# Install `add-apt-repository` command from the `software-properties-common` package.
# `cargo`, `libssl-dev`, `pkg-config` is needed by efs-tools later
RUN apt-get update \
    && apt-get install -y  \
    software-properties-common \
    sudo \
    rsync \
    ssh \
    git \
    git-extras \
    openssh-server \
    nginx \
    unzip \
    bzip2 \
    tree \
    colordiff \
    wdiff \
    most \
    mosh \
    nano \
    curl \
    wget \
    tmux \
    vim \
    man \
    man-db \
    binutils nfs-common stunnel4 \
    cargo libssl-dev pkg-config\
    iputils-ping \
    python3-pip \
    python3-venv \
    python3-dev \
    pipx \
    fish \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# https://askubuntu.com/questions/1413421/how-to-install-older-version-of-python-in-ubuntu-22-04
RUN add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update \
    && apt-get install -y python3.9 python3.9-venv \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install awscli via the official route
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
RUN wget "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -qO /tmp/awscliv2.zip \
    && unzip /tmp/awscliv2.zip -d /tmp/awscli \
    && /tmp/awscli/aws/install \
    && which aws \
    && rm -rf /tmp/aws \
    && rm -rf /tmp/awscliv2.zip

# Needed to mount AWS EFS file system using this command
# sudo mount -t efs -o tls,ro fs-<id>:/ /mnt/efs
# https://docs.aws.amazon.com/efs/latest/ug/installing-amazon-efs-utils.html#installing-other-distro
# We install AWS efs-client just so that we don't need to install later on.
# We should've already installed git and binutils above.
# Requires `cargo`, `libssl-dev`, `pkg-config` packages to be installed by apt-get
RUN git clone https://github.com/aws/efs-utils /tmp/efs-utils \
    && cd /tmp/efs-utils \
    && ./build-deb.sh \
    && apt-get update \
    && apt-get -y install /tmp/efs-utils/build/amazon-efs-utils*deb \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && cd $HOME \
    && rm -rf /tmp/efs-utils

# Create $ML_USER non-interactively and add it to sudo group. See
# (1) https://stackoverflow.com/questions/25845538/how-to-use-sudo-inside-a-docker-container
# (2) https://askubuntu.com/questions/7477/how-can-i-add-a-new-user-as-sudoer-using-the-command-line
RUN useradd -m ${ML_USER} \
    && adduser ${ML_USER} sudo \
    && echo ${ML_USER}:${ML_USER_PASSWORD} | chpasswd
RUN usermod -s `which fish` ${ML_USER}

# Copy into the ML_USER's home folder and we will later run chown
RUN mkdir -p /home/${ML_USER}/toolbox/bin
RUN mkdir -p /home/${ML_USER}/.git/templates
RUN mkdir -p /home/${ML_USER}/.config/fish/functions
RUN mkdir -p /home/${ML_USER}/.config/fish/conf.d
COPY config.fish /home/${ML_USER}/.config/fish/config.fish

# Copy fish history for more productivity
RUN mkdir -p /home/${ML_USER}/.local/share/fish
COPY fish_history /home/${ML_USER}/.local/share/fish/fish_history

# Install fishmarks (this creates the .sdirs)
RUN rm -rf /home/${ML_USER}/.fishmarks \
    && git clone http://github.com/techwizrd/fishmarks /home/${ML_USER}/.fishmarks
COPY .sdirs /home/${ML_USER}/.sdirs

# Install Fish SSH agent (so you can store your ssh keys)
# Example usage: ssh-add ~/.ssh/id_rsa_github
RUN rm -rf /home/${ML_USER}/.fish-ssh-agent \
    && git clone https://github.com/tuvistavie/fish-ssh-agent.git /home/${ML_USER}/.fish-ssh-agent \
    && ln -fs /home/${ML_USER}/.fish-ssh-agent/functions/__ssh_agent_is_started.fish /home/${ML_USER}/.config/fish/functions/__ssh_agent_is_started.fish \
    && ln -fs /home/${ML_USER}/.fish-ssh-agent/functions/__ssh_agent_start.fish /home/${ML_USER}/.config/fish/functions/__ssh_agent_start.fish \
    && ls /home/${ML_USER}/.fish-ssh-agent/conf.d/*.fish | xargs -I{} ln -s {} /home/${ML_USER}/.config/fish/conf.d/

# Prepare to install virtualfish
COPY vf-update-env.fish /home/${ML_USER}/vf-update-env.fish
COPY vf-install-env.fish /home/${ML_USER}/vf-install-env.fish
RUN chmod +x /home/${ML_USER}/vf-install-env.fish
COPY pytorch.requirements.txt /home/${ML_USER}/pytorch.requirements.txt
COPY fish_prompt.fish /home/${ML_USER}/.config/fish/functions/fish_prompt.fish
COPY .vimrc /home/${ML_USER}/.vimrc

# Now, switch to our user
RUN chown -R ${ML_USER}:${ML_USER} /home/${ML_USER}
USER ${ML_USER}

# Install vim packages
RUN rm -rf /home/${ML_USER}/.vim/bundle/Vundle.vim \
    && mkdir -p /home/${ML_USER}/.vim/bundle \
    && git clone https://github.com/VundleVim/Vundle.vim.git /home/${ML_USER}/.vim/bundle/Vundle.vim \
    && vim +PluginInstall +qall

# Create .ssh folder to keep authorized_keys later on
RUN mkdir -p /home/${ML_USER}/.ssh \
    && chmod 700 /home/${ML_USER}/.ssh

# Run fish and exit to initialize fish shell
RUN fish --command "echo 'Initializing and exiting fish shell'"

# Download and install Miniconda
ENV MINICONDA_INSTALLATION=/home/${ML_USER}/toolbox/miniconda3
ENV CONDA_NO_PATH_UPDATE=true
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -qO /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p ${MINICONDA_INSTALLATION} \
    && rm /tmp/miniconda.sh \
    && chmod +x ${MINICONDA_INSTALLATION}/condabin/conda \
    && ln -fs ${MINICONDA_INSTALLATION}/etc/fish/conf.d/conda.fish /home/${ML_USER}/.config/fish/conf.d/conda.fish \
    && ${MINICONDA_INSTALLATION}/condabin/conda config --set always_yes yes \
    && ${MINICONDA_INSTALLATION}/condabin/conda update -q conda

# Augment path so we can call ipython and jupyter
# Using $HOME would just use the root user. $HOME works with the RUN directive
# which uses the userid of the user in the relevant USER directive. But ENV
# doesn't seem to use this. See https://stackoverflow.com/questions/57226929/dockerfile-docker-directive-to-switch-home-directory
# This is probably why variables set by ENV directive are available to all
# users as mentioned in https://stackoverflow.com/questions/32574429/dockerfile-create-env-variable-that-a-user-can-see
ENV PATH=/home/${ML_USER}/toolbox/bin:$PATH:/home/${ML_USER}/.local/bin
# ENV PATH=/home/${ML_USER}/toolbox/bin:$PATH:/home/${ML_USER}/.local/bin:${MINICONDA_INSTALLATION}/condabin

# We remove pip cache so docker can store the layer for later reuse.
# Install a pytorch environment using virtualfish
# This virtualenv will be installed for the ML_USER but not for the root user.
RUN pipx install virtualfish==2.5.5 --pip-args="--no-cache-dir" \
    && mkdir -p /home/${ML_USER}/.virtualenvs \
    && fish --command "which vf; and vf install" \
    && fish /home/${ML_USER}/vf-install-env.fish pytorch /home/${ML_USER}/pytorch.requirements.txt \
    && rm -rf /home/${ML_USER}/.cache/pip

# Set the working directory as the home directory of $ML_USER
# Using $HOME would not work and is not a recommended way.
# See https://stackoverflow.com/questions/57226929/dockerfile-docker-directive-to-switch-home-directory
WORKDIR /home/${ML_USER}
