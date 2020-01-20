#!/bin/bash 

VI_CONTAINER="vault"
VI_PROJECT="frickeldave"
VI_VAULTURL="https://localhost"
VI_VAULTPORT="7443"

function main() {
    
    parse_input $@
    vault_get_token
    vault_check_status
    
    if [ "$VI_INIT" == "1" ]; then vault_init; fi
    if [ "$VI_SECRET" == "1" ]; then vault_add_secrets; fi
    if [ "$VI_AUTH" == "1" ]; then echo "handle auth"; fi

    cleanup 0
}

function parse_input() {

	echo "Parse input"

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
                echo "   Add screts to vault server"
                ;;
            --container) 
                VI_CONTAINER=$VI_VALUE
				echo "   VI_CONTAINER=$VI_CONTAINER"
                ;;
            --project)
                VI_PROJECT=$VI_VALUE
				echo "   VI_PROJECT=$VI_PROJECT"
                ;;
            --vaulturl)
                VI_VAULTURL=$VI_VALUE
				echo "   VI_VAULTURL=$VI_VAULTURL"
                ;;
            --vaultport)
                VI_VAULTPORT=$VI_VALUE
				echo "   VI_VAULTPORT=$VI_VAULTPORT"
                ;;
            *) # Handles all unknown parameter
                echo "   Ignoring unknown parameter \"$PARAM\""
                ;;
        esac
        shift
    done
}

function vault_unseal() {
    
    echo "unseal the vault"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'";grep "Unseal Key" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " " | while read -r line; do /home/appuser/app/vault operator unseal $line; done'  #> /dev/null 2>&1

	if [ "$?" == "0" ]
	then
		echo "   success"
	else
		echo "   failed"
        
        cleanup 1
	fi
}

function vault_get_token() {

    echo "Get vault token from within container"
    while ! docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'ls /home/appuser/data/vault_keys.txt -al' > /dev/null 2>&1
    do
        echo "   Wait another 5s for vault server"
        sleep 5
    done
    echo "   Wait another 5s for vault server"
    sleep 5

    VI_TOKEN=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'egrep "^Initial Root Token:" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " "')
    if [ "$VI_TOKEN" == "" ]; 
    then 
         echo "   Failed. Leaving script"
         cleanup 1
    fi
}

function vault_check_status() {
   
    echo "check status of vault server with address ${VI_VAULTURL}:${VI_VAULTPORT}"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault operator key-status' > /dev/null 2>&1
    local ret=$?

    if [ $ret -eq 2 ]
    then 
        echo "Vault server sealed. Try to unseal"
        vault_unseal
        if [ $? -ne 0 ]
        then 
            echo "Failed to unseal vault"
            cleanup 1
        fi
    elif [ $ret -eq 0 ]
    then
        echo "Everything fine"
    else
        echo "Vault server not working" 
        cleanup 1
    fi
}

function vault_init() {

    ########################################################################
    # Secret store
    ########################################################################

    echo "Create secret store"
    echo "   Check if ""$VI_PROJECT"" kv-store exist"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets list | grep '$VI_PROJECT'' > /dev/null 2>&1
    then
        echo "   kv-store found. Delete it."
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets disable '$VI_PROJECT'' > /dev/null 2>&1
    fi

    echo "   Create new secret store"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault secrets enable -version=2 -path='${VI_PROJECT}' kv' #> /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed to create secret store. Leaving script."
        cleanup 1
    fi

    ########################################################################
    # AppRole Authentication
    ########################################################################

    echo "Create AppRole Authentication method"
    echo "   Check if AppRole Authentication method exists"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth list | grep approle_'${VI_PROJECT}'' > /dev/null 2>&1
    then
        echo "   Delete Authentication method AppRole"
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth disable approle_'${VI_PROJECT}'' > /dev/null 2>&1
    fi
    echo "   Create Authentication method AppRole"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth enable -path approle_'${VI_PROJECT}' approle' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        cleanup 1
    fi

    ########################################################################
    # Userpass Authentication
    ########################################################################

    echo "Create Userpass Authentication method"
    echo "   Check if Userpass Authentication method exists"
    if docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth list | grep userpass_'${VI_PROJECT}'' > /dev/null 2>&1
    then
        echo "   Delete Userpass authentication method"
        docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth disable userpass_'${VI_PROJECT}'' > /dev/null 2>&1
    fi
    echo "   Create Userpass Authentication method"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault auth enable -path=userpass_'${VI_PROJECT}' userpass' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        cleanup 1
    fi
    
    ########################################################################
    # Admin Policy and user
    ########################################################################
    
    echo "Create admin policy (${VI_PROJECT}_admin)"
    echo 'path "'${VI_PROJECT}'/systems*" {' > /tmp/pol.hcl
    echo '       capabilities = ["create", "read", "update", "delete", "list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${VI_PROJECT}'/*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    echo "   Copy admin policy into docker container"
    docker cp /tmp/pol.hcl "${VI_PROJECT}_${VI_CONTAINER}_1:/tmp/pol.hcl"
    
    echo "   Upload policy to vault"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault policy write '${VI_PROJECT}'_admin /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        cleanup 1
    fi
    
    echo "   Create admin user (${VI_PROJECT}_admin)"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write auth/userpass_'${VI_PROJECT}'/users/'${VI_PROJECT}'_admin password=test policies="'${VI_PROJECT}'_admin"' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        cleanup 1
    fi

    echo "   User successful created. You can login now with command ""vault login -method=userpass -path=userpass_${VI_PROJECT} username=${VI_PROJECT}_admin password=*****"
}

function vault_add_secrets() {
    
    ########################################################################
    # Init secrets
    ########################################################################

    local projecttimestamp=`date +%Y-%m-%d_%H:%M:%S`
    local secretvalue=${projecttimestamp}
    vault_write_kvsecret "/init" "created" "$secretvalue" "put"
    
    ########################################################################
    # Gitea secrets
    ########################################################################

    #TODO: This can be done more efficent by iterating through all values with jq

    # vault secrets
    echo "Send certificate secrets to vault"
    secretvalue=$(config_get_value "certificates" "CRT_VALIDITY")
    vault_write_kvsecret "/certificates" "CRT_VALIDITY" "$secretvalue" "put"
    secretvalue=$(config_get_value "certificates" "CRT_C")
    vault_write_kvsecret "/certificates" "CRT_C" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_S")
    vault_write_kvsecret "/certificates" "CRT_S" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_L")
    vault_write_kvsecret "/certificates" "CRT_L" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_OU")
    vault_write_kvsecret "/certificates" "CRT_OU" "$secretvalue" "patch"
    secretvalue=$(config_get_value "certificates" "CRT_CN")
    vault_write_kvsecret "/certificates" "CRT_CN" "$secretvalue" "patch"

    # mariadb secrets
    echo "Send mariadb secrets to vault"
    secretvalue=$(config_get_value "mariadb" "MDB_ROOTPWD")
    vault_write_kvsecret "/systems/mariadb" "MDB_ROOTPWD" "$secretvalue" "put"
    secretvalue=$(config_get_value "mariadb" "MDB_ADMINUSER")
    vault_write_kvsecret "/systems/mariadb" "MDB_ADMINUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_BACKUPUSER")
    vault_write_kvsecret "/systems/mariadb" "MDB_BACKUPUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_ADMINPWD")
    vault_write_kvsecret "/systems/mariadb" "MDB_ADMINPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_BACKUPPWD")
    vault_write_kvsecret "/systems/mariadb" "MDB_BACKUPPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_HEALTHPWD")
    vault_write_kvsecret "/systems/mariadb" "MDB_HEALTHPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_COLLATION")
    vault_write_kvsecret "/systems/mariadb" "MDB_COLLATION" "$secretvalue" "patch"
    secretvalue=$(config_get_value "mariadb" "MDB_CHARACTERSET")
    vault_write_kvsecret "/systems/mariadb" "MDB_CHARACTERSET" "$secretvalue" "patch"

    # gitea secrets
    echo "Send gitea secrets to vault"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLADMINUSER")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLADMINUSER" "$secretvalue" "put"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLADMINPASSWORD")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLADMINPASSWORD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHOST")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLHOST" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLPORT")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLPORT" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLDB")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLDB" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLUSERNAME")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLUSERNAME" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLPASSWORD")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLPASSWORD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHEALTHUSER")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLHEALTHUSER" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_MYSQLHEALTHPWD")
    vault_write_kvsecret "/systems/gitea" "GT_MYSQLHEALTHPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_PROTOCOL")
    vault_write_kvsecret "/systems/gitea" "GT_PROTOCOL" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_HTTP_PORT")
    vault_write_kvsecret "/systems/gitea" "GT_HTTP_PORT" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMIN")
    vault_write_kvsecret "/systems/gitea" "GT_INITIALADMIN" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMINPWD")
    vault_write_kvsecret "/systems/gitea" "GT_INITIALADMINPWD" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_INITIALADMINMAIL")
    vault_write_kvsecret "/systems/gitea" "GT_INITIALADMINMAIL" "$secretvalue" "patch"
    secretvalue=$(config_get_value "gitea" "GT_REMOVE_DB")
    vault_write_kvsecret "/systems/gitea" "GT_REMOVE_DB" "$secretvalue" "patch"

}

function vault_add_roles() {

    vault_write_apppolicy "certificates"
    vault_write_approle "mariadb"
    vault_write_approle "vault"
    vault_write_approle "gitea"

    local roleid=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault read -format=json auth/approle_frickeldave/role/gitea/role-id | jq -r ".data.role_id"')
    echo "Extracted roleid is: $roleid"

    local secretid=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write -f -format=json auth/approle_frickeldave/role/gitea/secret-id | jq -r ".data.secret_id"')
    echo "Extracted secretid is: $secretid"

    local apptoken=$(docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write -format=json auth/approle_frickeldave/login role_id='${roleid}' secret_id='${secretid}' | jq -r ".auth.client_token"')
    echo "Extracted app token is: $apptoken"
}

function vault_write_kvsecret() {

    local secretpath=$1
    local secretname=$2
    local secretvalue=$3
    local secretmethod=$4

    echo "Create secret \"$secretname\" in path \"${VI_PROJECT}${secretpath}\" with method \"$secretmethod\""
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault kv '$secretmethod' '${VI_PROJECT}${secretpath}' '${secretname}'='${secretvalue}'' > /dev/null 2>&1
    if [ ! "$?" == "0" ]; 
    then 
        echo "   failed to create secret. Leaving script"
        cleanup 1
    fi
}

function vault_write_approle() {
    
    local appname=$1

    echo "Create $appname role"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault write auth/approle_'${VI_PROJECT}'/role/gitea token_policies='${VI_PROJECT}'_systems_'${appname}' token_ttl=1h token_max_ttl=4h' > /dev/null 2>&1
    if [ ! $? = 0 ]; 
    then 
        echo "   failed. Leaving script"
        cleanup 1
    fi
}

function vault_write_apppolicy() {
    
    local appname=$1

    echo "Create app policy (${VI_PROJECT}_systems_${appname})"
    echo 'path "'${VI_PROJECT}'/systems/'${appname}'*" {' > /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${VI_PROJECT}'/certificates*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    echo "   Copy app policy into docker container"
    docker cp /tmp/pol.hcl "${VI_PROJECT}_${VI_CONTAINER}_1:/tmp/pol.hcl"
    
    echo "   Upload policy to vault"
    docker exec -it ${VI_PROJECT}_${VI_CONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${VI_TOKEN}'"; export VAULT_ADDR="'${VI_VAULTURL}':'${VI_VAULTPORT}'"; //home//appuser//app//vault policy write '${VI_PROJECT}'_systems_'${appname}' /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        echo "   failed. Leaving script."
        cleanup 1
    fi
}

function config_get_value() {
    
    local valuecategory=$1
    local valuename=$2

    local value=$(docker run -it ${VI_PROJECT}/build sh -c 'jq -r "'.$valuecategory.$valuename'" "/home/appuser/app/vault-init.json"')
    echo "$value"
}

function debug_vars() {
    echo "##################################"
    echo "### Debug output start"
    echo "##################################"
    echo "Project:      ${VI_PROJECT}"
    echo "Container:    ${VI_CONTAINER}"
    echo "Token:        ${VI_TOKEN}"
    echo "URL:          ${VI_VAULTURL}"
    echo "Port:         ${VI_VAULTPORT}"
    echo "##################################"
    echo "### Debug output end"
    echo "##################################"
}

function cleanup() {
    
    local exitcode=$1

    echo "Cleanup variables"

    VI_PROJECT=""
    VI_CONTAINER=""
    VI_TOKEN=""
    VI_VAULTURL=""
    VI_VAULTPORT=""

    echo "exit with code: $exitcode"
    exit $exitcode
}

main $@