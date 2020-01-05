#!/bin/bash

RET=$(docker ps -a -q)

if [[ -n $RET ]]
then
	echo "stop all running containers"
	docker stop $(docker ps -a -q) #>> /dev/null 2>&1
	RET=$?
	if [ ! $RET == 0 ]
	then 
		echo "Failed with exit code $RET"
		exit 1
	fi

	echo "delete all running containers"
	docker rm $(docker ps -a -q) >> /dev/null 2>&1
	RET=$?
	if [ ! $RET == 0 ]
	then 
		echo "Failed with exit code $RET"
		exit 1
	fi
fi

RET=$(docker images -q)

if [[ -n $RET ]]
then
	echo "delete all docker images"
	docker rmi $(docker images -q) -f >> /dev/null 2>&1
	RET=$?
	if [ ! $RET == 0 ]
	then 
		echo "Failed with exit code $RET"
		exit 1
	fi
fi

RET=$(docker volume ls -q)

if [[ -n $RET ]]
then
	echo "delete docker volume"
	docker volume rm $(docker volume ls -q) >> /dev/null 2>&1
	RET=$?
	if [ ! $RET == 0 ]
	then 
		echo "Failed with exit code $RET"
		exit 1
	fi
fi

echo "build new images"
docker-compose build

echo "start containers"
docker-compose --project-name frickeldave up -d