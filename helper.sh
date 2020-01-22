#!/bin/bash 

function log() {
    if [ "$HL_LOG" == "1" ]
    then
        echo $1 >&2
    fi
}
