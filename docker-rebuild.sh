#!/bin/bash

DR_CLEAN="false"
DR_PROJECT="frickeldave"
DR_SET_ALIAS="true"
DR_CONTAINER=""

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

	echo "      Delete existing volume ""$container_name"""
	if [ "$(docker volume ls -f name=${project_name}_${container_name}-data -q)" ]; then echo "         ...Volume exist, delete..."; docker volume rm ${project_name}_${container_name}-data > /dev/null; else echo "         ...Volume does not exist"; fi
}

function parse_input() {

    while [ "$1" != "" ]
    do
        local DR_PARAM=$(echo $1 | awk -F= '{print $1}')
        local DR_VALUE=$(echo $1 | awk -F= '{print $2}')

        case $DR_PARAM in

            --clean)
                DR_CLEAN="true"
                ;;	
			--build)
                DR_BUILD="true"
                ;;				
            --container) 
                DR_CONTAINER=$DR_VALUE
                ;;
            --project)
                DR_PROJECT=$DR_VALUE
                ;;
            --containershort)
                DR_CONTAINERSHORT=$DR_VALUE
                ;;
            *) # Handles all unknown parameter
                echo "   Ignoring unknown parameter \"$PARAM\"" "WARNING"
                ;;
        esac
        shift
    done

	if [ "$DR_PROJECT" == "" ]; then exit 1; fi
	if [ "$DR_CONTAINER" == "" ]; then exit 1; fi
	if [ "$DR_SETALIAS" == "true" ] && [ "$DR_CONTAINERSHORT" == "" ]; then exit 1; fi
}

function set_alias() {
	
	local project_name="$1"
	local container_name="$2"
	local container_short_name=${arr[$container_name]}
	echo "Create alias ""de$container_short_name=""docker exec -it ${project_name}_${container_name}_1 sh"""""
	alias de${container_short_name}='''docker exec -it '${project_name}'_'${container_name}'_1 sh'''
	alias dl$container_short_name='''docker logs '${project_name}'_'${container_name}'_1'''
}

function docker_build() {
	
	local project_name="$1"
	local container_name="$2"

	echo "(Re-)build image $2"
	docker-compose build "$container_name" > /dev/null 2>&1

	if [ "$?" == "0" ]
	then
		echo "   success"
	else
		echo "   failed"
	fi
}

function main() {   
    parse_input $@
	
	if [ "$DR_CLEAN" == "true" ] 
	then 
		docker_remove $DR_PROJECT $DR_CONTAINER
	fi 

	if [ "$DR_SETALIAS" == "true" ] 
	then 
		set_alias $DR_PROJECT $DR_CONTAINER
	fi

	if [ "$DR_BUILD" == "true" ] 
	then 
		docker_build $DR_PROJECT $DR_CONTAINER
	fi
}
main $@