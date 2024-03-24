#!/usr/bin/env fish

# Fish lists are not zero-indexed
set VF_ENV_NAME $argv[1]

vf activate "$VF_ENV_NAME"
pip install --upgrade pip
pip install --no-cache-dir $argv[2..-1]
vf deactivate
