#!/usr/bin/env fish

# Fish lists are not zero-indexed
vf new $argv[1]
pip install --upgrade pip
pip install --no-cache-dir -r "/home/$USER/$argv[1].requirements.txt"
vf deactivate
