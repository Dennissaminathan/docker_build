#!/bin/bash

DR_CLEAN="false"
DR_PRUNE="false"
DR_PROJECT="frickeldave"
declare -a arr=('alpine' 'go' 'coredns' 'mariadb' 'nginx' 'vault');

function docker_remove() { 

	local project_name="$1"
	local container_name="$2"

	echo "   remove container ""$container_name"""

	echo "      Stop existing container ""$container_name"""
	if [ "$(docker ps -f name=${project_name}_${container_name}_1 -q)" ]; then echo "         ...Container exist, stop..."; docker stop ${project_name}_${container_name}_1 > /dev/null; else echo "         ...Container does not exist"; fi

	echo "      Delete existing container ""$container_name"""
	if [ "$(docker ps -f name=${project_name}_${container_name}_1 -a -q)" ]; then echo "         ...Container exist, delete..."; docker rm ${project_name}_${container_name}_1 > /dev/null; else echo "         ...Container does not exist"; fi

	echo "      Delete existing image ""$container_name"""
	if [ "$(docker images ${project_name}/${container_name} -q)" ]; then echo "         ...Image exist, delete..."; docker rmi ${project_name}/${container_name} -f > /dev/null; else echo "         ...Image does not exist"; fi

	if [ "$DR_CLEAN" == "true" ] || [ "$DR_PRUNE" == "true" ]
	then
		echo "      Delete existing volume ""$container_name"""
		if [ "$(docker volume ls -f name=${project_name}_${container_name}-data -q)" ]; then echo "         ...Volume exist, delete..."; docker volume rm ${project_name}_${container_name}-data > /dev/null; else echo "         ...Volume does not exist"; fi
	fi
}

function parse_input() {

	echo "Parse input"

    while [ "$1" != "" ]
    do
        local DR_PARAM=$(echo $1 | awk -F= '{print $1}')
        local DR_VALUE=$(echo $1 | awk -F= '{print $2}')

        case $DR_PARAM in
            --prune)
                DR_PRUNE="true"
				echo "   DR_PRUNE=$DR_PRUNE"
                ;;  
            --clean)
                DR_CLEAN="true"
				echo "   DR_CLEAN=$DR_CLEAN"
                ;;				
            --container) 
                DR_CONTAINER=$DR_VALUE
				echo "   DR_CONTAINER=$DR_CONTAINER"
                ;;
            --project)
                DR_PROJECT=$DR_VALUE
				echo "   DR_PROJECT=$DR_PROJECT"
                ;;
            *) # Handles all unknown parameter
                echo "   Ignoring unknown parameter \"$PARAM\"" "WARNING"
                ;;
        esac
        shift
    done
}

function docker_remove_all() {
	
	echo "Remove all container"

	for i in "${arr[@]}"
	do 
		docker_remove $DR_PROJECT $i 
	done
}

function docker_prune() {
	echo "Prune all images and volumes"
	docker system prune -f -a
}

function main() {
    
    parse_input $@

	if [ "$DR_CONTAINER" == "" ]; then docker_remove_all; fi
	if [ "$DR_CONTAINER" == "" ] && [ $DR_PRUNE == "true" ]; then docker_remove_all; docker_prune; fi

}
main $@

docker-compose --project-name frickeldave up -d