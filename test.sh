#!/bin/bash 

function testf() {

    local container_name=$1

    echo $container_name

    buildcmd='jq -r \".containers[].'${container_name}'\" | to_entries[] | \"(.key):(.value)\" /home/appuser/app/vault-init.json'

    echo $buildcmd


}

foo="bar"
echo "1"
testf "$foo"
echo "2"
testf "dasc"
