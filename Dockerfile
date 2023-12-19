# Build:
# docker build --platform=linux/amd64 . -t ml-base
# Push:
# docker tag ml-base:latest ankurio/ml-base:latest
# docker push ankurio/ml-base:latest

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

# Create .ssh folder to keep authorized_keys later on
RUN mkdir -p /home/${ML_USER}/.ssh

# Install vim packages
RUN rm -rf /home/${ML_USER}/.vim/bundle/Vundle.vim \
    && mkdir -p /home/${ML_USER}/.vim/bundle \
    && git clone https://github.com/VundleVim/Vundle.vim.git /home/${ML_USER}/.vim/bundle/Vundle.vim
COPY .vimrc /home/${ML_USER}/.vimrc
COPY install-vim-plugins.sh /home/${ML_USER}/
RUN chmod +x /home/${ML_USER}/install-vim-plugins.sh \
    && /home/${ML_USER}/install-vim-plugins.sh

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
COPY vf-install-env.fish /home/${ML_USER}/vf-install-env.fish
RUN chmod +x /home/${ML_USER}/vf-install-env.fish
COPY pytorch.requirements.txt /home/${ML_USER}/pytorch.requirements.txt
COPY fish_prompt.fish /home/${ML_USER}/.config/fish/functions/fish_prompt.fish

# Download and install Miniconda
ENV CONDA_DIR=/opt/conda
#ENV PATH=$PATH:$CONDA_DIR/bin
RUN wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && /bin/bash /tmp/miniconda.sh -b -p $CONDA_DIR \
    && rm /tmp/miniconda.sh \
    && chmod +x $CONDA_DIR/bin/conda \
    && $CONDA_DIR/bin/conda config --set always_yes yes \
    && $CONDA_DIR/bin/conda update -q conda

# Now, switch to our user
RUN chown -R ${ML_USER}:${ML_USER} /home/${ML_USER}
USER ${ML_USER}

# Run fish and exit to initialize fish shell
RUN fish --command "echo 'Hello from Fish Shell!'"

# Augment path so we can call ipython and jupyter
# Using $HOME would just use the root user. $HOME works with the RUN directive
# which uses the userid of the user in the relevant USER directive. But ENV
# doesn't seem to use this. See https://stackoverflow.com/questions/57226929/dockerfile-docker-directive-to-switch-home-directory
# This is probably why variables set by ENV directive are available to all
# users as mentioned in https://stackoverflow.com/questions/32574429/dockerfile-create-env-variable-that-a-user-can-see
ENV PATH=/home/${ML_USER}/toolbox/bin:$PATH:/home/${ML_USER}/.local/bin:$CONDA_DIR/bin

# We remove pip cache so docker can store the layer for later reuse.
# Install a pytorch environment using virtualfish
RUN pipx install virtualfish --pip-args="--no-cache-dir" \
    && vf install \
    && mkdir -p /home/${ML_USER}/.virtualenvs \
    && fish /home/${ML_USER}/vf-install-env.fish pytorch && rm -rf /home/${ML_USER}/.cache/pip

# Set the working directory as the home directory of $ML_USER
# Using $HOME would not work and is not a recommended way.
# See https://stackoverflow.com/questions/57226929/dockerfile-docker-directive-to-switch-home-directory
WORKDIR /home/${ML_USER}
