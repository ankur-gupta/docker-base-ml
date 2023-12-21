#!/usr/bin/env fish

# Fish lists are not zero-indexed
set VF_ENV_NAME $argv[1]
set PATH_TO_REQUIREMENTS_FILE $argv[2]

# Check if PATH_TO_PYTHON_EXECUTABLE is provided, set a default if not
if test (count $argv) -ge 3
    set PATH_TO_PYTHON_EXECUTABLE $argv[3]
    vf new "$VF_ENV_NAME" -p "$PATH_TO_PYTHON_EXECUTABLE"
else
    vf new "$VF_ENV_NAME"
end
pip install --upgrade pip
pip install --no-cache-dir -r "$PATH_TO_REQUIREMENTS_FILE"
vf deactivate
