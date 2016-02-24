#!/bin/bash 
# Basic bash wrappers for running commands through ssh. 
# Assumes key based, passwordless ssh is working. 

# remote_cmd <target> <cmd> [args]
#  target: [user@]host[:port] 
# Runs cmd (optionally with args) on target. 
remote_cmd()
{
    target=$1
    shift
    ssh $target "$*"
}

# remote_script <target>
#  target: [user@]host[:port]
# Runs commands read from stdin on target
remote_script()
{
    cat | ssh $target
}
