#!/bin/bash 

function main() {
    

    if [ "$VI_GETROLEID" == "1" ]; then echo $(vault_get_role_id); fi
    if [ "$VI_GETSECRETID" == "1" ]; then echo $(vault_get_secret_id); fi
    if [ "$VI_GETAPPTOKEN" == "1" ]; then echo $(vault_get_apptoken); fi

}

function parse_input() {

	log "Parse input"

    while [ "$1" != "" ]
    do
        local VI_PARAM=$(echo $1 | awk -F= '{print $1}')
        local VI_VALUE=$(echo $1 | awk -F= '{print $2}')

        case $VI_PARAM in	
            --init)
                VI_INIT=1
                echo "   Init vault server"
                ;;
            --secret)
                VI_SECRET=1
                log "   Add screts to vault server"
                ;;
            --auth) 
                VI_AUTH=1
				log "   Add policies and roles"
                ;;
            --getsecretid) 
                VI_GETSECRETID=1
				log "   Get secret-id"
                ;;
            --getroleid) 
                VI_GETROLEID=1
				log "   Get role-id"
                ;; 
            --getapptoken) 
                VI_GETAPPTOKEN=1
				log "   Get apptoken"
                ;; 
            --appname) 
                VI_APPNAME=$VI_VALUE
				log "   VI_APPNAME=$VI_APPNAME"
                ;;
            --secretid) 
                VI_SECRETID=$VI_VALUE
				log "   VI_SECRETID=********"
                ;;   
            --roleid) 
                VI_ROLEID=$VI_VALUE
				log "   VI_ROLEID=********"
                ;;                                                 
            --container) 
                VI_CONTAINER=$VI_VALUE
				log "   VI_CONTAINER=$VI_CONTAINER"
                ;;                
            --project)
                VI_PROJECT=$VI_VALUE
				log "   VI_PROJECT=$project_name"
                ;;
            --vaulturl)
                VI_VAULTURL=$VI_VALUE
				log "   VI_VAULTURL=$VI_VAULTURL"
                ;;
            --vaultport)
                VI_VAULTPORT=$VI_VALUE
				log "   VI_VAULTPORT=$VI_VAULTPORT"
                ;;
            --log)
                VI_LOG=1
				log "   Logging enabled"
                ;;
            *) # Handles all unknown parameter
                log "   Ignoring unknown parameter \"$PARAM\""
                ;;
        esac
        shift
    done
}

function vault_get_root_token() {

    local project_name="$1"
	local container_name="$2"
	local root_token=""

    log "Get vault token from within container"
    while ! docker exec -it ${project_name}_${container_name}_1 sh -c 'ls /home/appuser/data/vault_keys.txt -al' > /dev/null 2>&1
    do
        log "   Wait another 5s for vault server"
        sleep 5
    done

    root_token=$(docker exec -it ${project_name}_${container_name}_1 sh -c 'egrep "^Initial Root Token:" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " "')
    if [ "$root_token" == "" ]; 
    then 
         log "   Failed. Leaving script"
         cleanup 1
    fi
    echo $root_token
}

function vault_check_status() {
   
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5

    log "check status of vault server with address ${vault_url}:${vault_port}"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault operator key-status' > /dev/null 2>&1
    local ret=$?

    if [ $ret -eq 2 ]
    then 
        log "Vault server sealed. Try to unseal"
        vault_unseal $project_name $container_name $vault_url $vault_port $vault_token
        if [ $? -ne 0 ]
        then 
            log "Failed to unseal vault"
            cleanup 1
        fi
    elif [ $ret -eq 0 ]
    then
        log "Vault is unsealed"
    else
        log "Vault server not working" 
        cleanup 1
    fi
}

function vault_unseal() {
    
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5

    log "unseal the vault"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_ADDR="'${vault_url}':'${vault_port}'";grep "Unseal Key" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " " | while read -r line; do /home/appuser/app/vault operator unseal $line; done'  > /dev/null 2>&1

	if [ "$?" == "0" ]
	then
		log "   success"
	else
		log "   failed"
        
        cleanup 1
	fi
}

function vault_init() {

    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5

    ########################################################################
    # Secret store
    ########################################################################

    log "$project_name secret store"
    log "   Check if \"$project_name\" kv-store exist"
    if docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault secrets list | grep '$project_name'' > /dev/null 2>&1
    then
        log "   kv-store found. Delete it."
        docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault secrets disable '$project_name'' > /dev/null 2>&1
    fi

    log "   Create new secret store"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault secrets enable -version=2 -path='${project_name}' kv' #> /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed to create secret store. Leaving script."
        cleanup 1
    fi

    ########################################################################
    # AppRole Authentication
    ########################################################################

    log "Create AppRole Authentication method"
    log "   Check if AppRole Authentication method exists"
    if docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth list | grep approle_'${project_name}'' > /dev/null 2>&1
    then
        log "   Delete Authentication method AppRole"
        docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth disable approle_'${project_name}'' > /dev/null 2>&1
    fi
    log "   Create Authentication method AppRole"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth enable -path approle_'${project_name}' approle' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        cleanup 1
    fi

    ########################################################################
    # Userpass Authentication
    ########################################################################

    log "Create Userpass Authentication method"
    log "   Check if Userpass Authentication method exists"
    if docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth list | grep userpass_'${project_name}'' > /dev/null 2>&1
    then
        log "   Delete Userpass authentication method"
        docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth disable userpass_'${project_name}'' > /dev/null 2>&1
    fi
    log "   Create Userpass Authentication method"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault auth enable -path=userpass_'${project_name}' userpass' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        cleanup 1
    fi
    
    ########################################################################
    # Admin Policy and user
    ########################################################################
    
    log "Create admin policy (${project_name}_admin)"
    echo 'path "'${project_name}'/systems*" {' > /tmp/pol.hcl
    echo '       capabilities = ["create", "read", "update", "delete", "list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${project_name}'/*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    log "   Copy admin policy into docker container"
    docker cp /tmp/pol.hcl "${project_name}_${container_name}_1:/tmp/pol.hcl"
    
    log "   Upload policy to vault"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault policy write '${project_name}'_admin /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        cleanup 1
    fi
    
    log "   Create admin user (${project_name}_admin)"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault write auth/userpass_'${project_name}'/users/'${project_name}'_admin password=test policies="'${project_name}'_admin"' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        cleanup 1
    fi

    log "   User successful created. You can login now with command ""vault login -method=userpass -path=userpass_${project_name} username=${project_name}_admin password=*****"
}

function vault_add_secrets() {
    
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5

    ########################################################################
    # "Init" secrets            
    ########################################################################

    local projecttimestamp=`date +%Y-%m-%d_%H:%M:%S`
    local secretvalue=${projecttimestamp}
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/init" "created" "$secretvalue" "put"
    
    ########################################################################
    # Gitea secrets
    ########################################################################

    #TODO: This can be done more efficent by iterating through all values with jq

    # vault secrets
    log "Send certificate secrets to vault"
    secretvalue=$(config_get_value "certificates" "CRT_VALIDITY" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_VALIDITY" "$secretvalue" "put"
    secretvalue=$(config_get_value "certificates" "CRT_C" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_C" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_S" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_S" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_L" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_L" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_OU" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_OU" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_CN" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/certificates" "CRT_CN" "$secretvalue" "patch"

    # mariadb secrets
    log "Send mariadb secrets to vault"
    secretvalue=$(config_get_value "mariadb" "MDB_ROOTPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_ROOTPWD" "$secretvalue" "put"
    secretvalue=$(config_get_value "mariadb" "MDB_ADMINUSER" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_ADMINUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_BACKUPUSER" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_BACKUPUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_ADMINPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_ADMINPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_BACKUPPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_BACKUPPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_HEALTHPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_HEALTHPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_COLLATION" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_COLLATION" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_CHARACTERSET" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/mariadb" "MDB_CHARACTERSET" "$secretvalue" "patch"

    # gitea secrets
    log "Send gitea secrets to vault"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLADMINUSER" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLADMINUSER" "$secretvalue" "put"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLADMINPASSWORD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLADMINPASSWORD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHOST" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLHOST" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLPORT" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLPORT" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLDB" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLDB" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLUSERNAME" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLUSERNAME" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLPASSWORD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLPASSWORD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHEALTHUSER" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLHEALTHUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHEALTHPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_MYSQLHEALTHPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_PROTOCOL" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_PROTOCOL" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_HTTP_PORT" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_HTTP_PORT" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMIN" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_INITIALADMIN" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMINPWD" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_INITIALADMINPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMINMAIL" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_INITIALADMINMAIL" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_REMOVE_DB" $project_name)
    vault_write_kvsecret "$project_name" "$container_name" "$vault_url" "$vault_port" "$vault_token" "/systems/gitea" "GT_REMOVE_DB" "$secretvalue" "patch"

}

function vault_write_kvsecret() {

    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5

    local secretpath=$6
    local secretname=$7
    local secretvalue=$8
    local secretmethod=$9

    log "Create secret \"$secretname\" in path \"${project_name}${secretpath}\" with method \"$secretmethod\""
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault kv '$secretmethod' '${project_name}${secretpath}' '${secretname}'='${secretvalue}'' > /dev/null 2>&1
    if [ ! "$?" == "0" ]; 
    then 
        log "   failed to create secret. Leaving script"
        cleanup 1
    fi
}

function vault_write_approle() {
    
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5
    local app_name=$6

    log "Create $app_name role"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault write auth/approle_'${project_name}'/role/'${app_name}' token_policies='${project_name}'_systems_'${app_name}' token_ttl=1h token_max_ttl=4h' > /dev/null 2>&1
    if [ ! $? = 0 ]; 
    then 
        log "   failed. Leaving script"
        cleanup 1
    fi
}

function vault_write_apppolicy() {
    
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5
    local app_name=$6

    log "Create app policy (${project_name}_systems_${app_name})"
    echo 'path "'${project_name}'/systems/'${app_name}'*" {' > /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${project_name}'/certificates*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    log "   Copy app policy into docker container"
    docker cp /tmp/pol.hcl "${project_name}_${container_name}_1:/tmp/pol.hcl"
    
    log "   Upload policy to vault"
    docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault policy write '${project_name}'_systems_'${app_name}' /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        cleanup 1
    fi
}

function vault_get_role_id() {
    
    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5
    local app_name=$6

    log 'get role id from auth/approle_'${project_name}'/role/'${app_name}'/role-id'
    local roleid=$(docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault read -format=json auth/approle_'${project_name}'/role/'${app_name}'/role-id | jq -r ".data.role_id"')
    echo "$roleid"
}

function vault_get_secret_id() {

    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5
    local app_name=$6

    log 'get secret id from auth/approle_'${project_name}'/role/'${app_name}'/secret-id'
    local secretid=$(docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault write -f -format=json auth/approle_'${project_name}'/role/'${app_name}'/secret-id | jq -r ".data.secret_id"')
    echo "$secretid"

}

function vault_get_apptoken() {

    local project_name=$1
	local container_name=$2
    local vault_url=$3
    local vault_port=$4
	local vault_token=$5
    local role_id=$6
    local secret_id=$7

    log "Get apptoken with role_id='${role_id}' and secret_id=********"
    local apptoken=$(docker exec -it ${project_name}_${container_name}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${vault_token}'"; export VAULT_ADDR="'${vault_url}':'${vault_port}'"; //home//appuser//app//vault write -format=json auth/approle_'${project_name}'/login role_id='${role_id}' secret_id='${secret_id}' | jq -r ".auth.client_token"')
    echo "$apptoken"

}