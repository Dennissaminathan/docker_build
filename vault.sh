#!/bin/bash 

function vault_initial_setup() {
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for vault availability"
    vault_wait_for_startup

    log "get the root token out of the vault docker container"
    local root_token=$(vault_get_root_token "$MC_VAULTCONTAINER")
    
    log "check if vault is running and unsealed and unseal if needed"
    vault_check_status "$root_token"

    log "Create a kv_v2 secret store for the project, activate approle and userpass authentication, create admin policies"
    vault_init "$root_token"

    log "Write secrets from json to vault-server"
    vault_add_secrets "$root_token"

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check vault availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    cnt=0
    while ! docker exec -it ${MC_PROJECT}_vault_1 sh -c "${cmd}" > /dev/null 2>&1; do
        ((cnt++))
        log "firststart_finished.flg not available. Wait 15s and try again ..."
        sleep 15s
        if [ $cnt -eq 21 ]
        then
            log "Failed to start vault"
            exit 1
        fi
    done

    log "vault setup finished."

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_get_root_token() {

	local root_token=""

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Get vault token from within container"
    while ! docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'ls /home/appuser/data/vault_keys.txt -al' > /dev/null 2>&1
    do
        log "Wait another 5s for vault server"
        sleep 5
    done

    root_token=$(docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'egrep "^Initial Root Token:" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " "')
    if [ "$root_token" == "" ]; 
    then 
         log "Failed to get root token. Leaving script"
         exit 1
    fi
    # TODO: Its OK to print it out, but it must be changed at the end of the setup
    log "Initial root token is: $root_token"

    MC_LOGINDENT=$((MC_LOGINDENT-3))

    echo $root_token
}

function vault_check_status() {
   
	local root_token=$1

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check status of vault server with address ${MC_VAULTURL}:${MC_VAULTPORT}"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault operator key-status' > /dev/null 2>&1
    local ret=$?

    if [ $ret -eq 2 ]
    then 
        log "Vault server sealed. Try to unseal"
        vault_unseal $root_token
        if [ $? -ne 0 ]
        then 
            log "Failed to unseal vault"
            exit 1
        fi
    elif [ $ret -eq 0 ]
    then
        log "Vault is unsealed"
    else
        log "Vault server not working"
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_unseal() {

	local root_token=$1

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "unseal the vault"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'";grep "Unseal Key" /home/appuser/data/vault_keys.txt | cut -f2- -d: | tr -d " " | while read -r line; do /home/appuser/app/vault operator unseal $line; done'  > /dev/null 2>&1

	if [ "$?" == "0" ]
	then
		log "   success"
	else
		log "   failed"
        exit 1
	fi

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_init() {

    local root_token=$1

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "$MC_PROJECT secret store"
    log "   Check if \"$MC_PROJECT\" kv-store exist"
    if docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault secrets list | grep '$MC_PROJECT'' > /dev/null 2>&1
    then
        log "   kv-store found. Delete it."
        docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault secrets disable '$MC_PROJECT'' > /dev/null 2>&1
    fi

    log "   Create new secret store"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault secrets enable -version=2 -path='${MC_PROJECT}' kv' #> /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed to create secret store. Leaving script."
        exit 1
    fi

    ########################################################################
    # AppRole Authentication
    ########################################################################

    log "Create AppRole Authentication method"
    log "Check if AppRole Authentication method exists"
    if docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth list | grep approle_'${MC_PROJECT}'' > /dev/null 2>&1
    then
        log "Delete Authentication method AppRole"
        docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth disable approle_'${MC_PROJECT}'' > /dev/null 2>&1
    fi
    log "Create Authentication method AppRole"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth enable -path approle_'${MC_PROJECT}' approle' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi

    ########################################################################
    # Userpass Authentication
    ########################################################################

    log "Create Userpass Authentication method"
    log "Check if Userpass Authentication method exists"
    if docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth list | grep userpass_'${MC_PROJECT}'' > /dev/null 2>&1
    then
        log "Delete Userpass authentication method"
        docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth disable userpass_'${MC_PROJECT}'' > /dev/null 2>&1
    fi
    log "Create Userpass Authentication method"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault auth enable -path=userpass_'${MC_PROJECT}' userpass' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi
    
    ########################################################################
    # Admin Policy and user
    ########################################################################
    
    log "Create admin policy (${MC_PROJECT}_admin)"
    echo 'path "'${MC_PROJECT}'/systems*" {' > /tmp/pol.hcl
    echo '       capabilities = ["create", "read", "update", "delete", "list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${MC_PROJECT}'/*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["list"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    log "Copy admin policy into docker container"
    docker cp /tmp/pol.hcl "${MC_PROJECT}_${MC_VAULTCONTAINER}_1:/tmp/pol.hcl"
    
    log "Upload policy to vault"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault policy write '${MC_PROJECT}'_admin /tmp/pol.hcl' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi
    
    log "Create admin user (${MC_PROJECT}_admin)"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault write auth/userpass_'${MC_PROJECT}'/users/'${MC_PROJECT}'_admin password=test policies="'${MC_PROJECT}'_admin"' > /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "Failed. Leaving script."
        exit 1
    fi

    log "User successful created. You can login now with command ""vault login -method=userpass -path=userpass_${MC_PROJECT} username=${MC_PROJECT}_admin password=*****"
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_add_secrets() {
    
	local root_token=$1

    local projecttimestamp=`date +%Y-%m-%d_%H:%M:%S`
    local secretvalue=${projecttimestamp}

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    vault_write_kvsecret "$root_token" "/init" "created" "$secretvalue" "put"
    
    # TODO: DO NOT KNOW; WHERE CERTIFICATE DETAILS ARE CREATE. DUMB DEVELOPER.
    log "Write policy to access certificate details"
    vault_write_apppolicy $root_token "certificates"

    ########################################################################
    # Send container secrets to vault
    ########################################################################
    
    for c in "${containers[@]}"
    do
        local container_values=$(config_get_container_values "$c")
        IFS=';' read -ra kvparr <<< "$container_values"    #Convert string to array
        local cnt=0
        for kvp in ${kvparr[@]}
        do
            if [ $cnt -eq 0 ]; then method="put"; else method="patch"; fi
            local param=$(echo $kvp | awk -F= '{print $1}')
            local value=$(echo $kvp | awk -F= '{print $2}')

            vault_write_kvsecret "${root_token}" "/containers/${c}" "${param}" "${value}" "${method}"
            ((cnt++))
        done

        log "Write approle for $c"
        vault_write_approle $root_token "$c"
        log "Write apppolicy for $c"
        vault_write_apppolicy $root_token "$c"

    done
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_write_kvsecret() {

	local root_token=$1
    local secretpath=$2
    local secretname=$3
    local secretvalue=$4
    local secretmethod=$5

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create secret \"$secretname\" in path \"${MC_PROJECT}/${secretpath}\" with method \"$secretmethod\""
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault kv '$secretmethod' '${MC_PROJECT}${secretpath}' '${secretname}'='${secretvalue}'' > /dev/null 2>&1
    if [ ! "$?" == "0" ]; 
    then 
        log "   failed to create secret. Leaving script"
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_write_approle() {

    local root_token=$1
    local app_name=$2

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create $app_name role"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault write auth/approle_'${MC_PROJECT}'/role/'${app_name}' token_policies='${MC_PROJECT}'_systems_'${app_name}' token_ttl=1h token_max_ttl=4h' > /dev/null 2>&1
    if [ ! $? = 0 ]; 
    then 
        log "   failed. Leaving script"
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_write_apppolicy() {
    
    local root_token=$1
    local app_name=$2

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create app policy (${MC_PROJECT}_systems_${app_name})"
    echo 'path "'${MC_PROJECT}'/systems/'${app_name}'*" {' > /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    echo 'path "'${MC_PROJECT}'/certificates*" {' >> /tmp/pol.hcl
    echo '       capabilities = ["read"]' >> /tmp/pol.hcl
    echo '}' >> /tmp/pol.hcl
    
    log "   Copy app policy into docker container"
    docker cp /tmp/pol.hcl "${MC_PROJECT}_${MC_VAULTCONTAINER}_1:/tmp/pol.hcl"

    log "   Upload policy to vault"
    docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault policy write '${MC_PROJECT}'_systems_'${app_name}' /tmp/pol.hcl' #> /dev/null 2>&1
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function vault_get_role_id() {
    
    local app_name=$1

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    local root_token=$(vault_get_root_token "$MC_VAULTCONTAINER")

    log 'get role id from auth/approle_'${MC_PROJECT}'/role/'${app_name}'/role-id'
    local roleid=$(docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault read -format=json auth/approle_'${MC_PROJECT}'/role/'${app_name}'/role-id | jq -r ".data.role_id"')

    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
    echo "$roleid"
}

function vault_get_secret_id() {

	local root_token=$1
    local app_name=$2

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log 'get secret id from auth/approle_'${MC_PROJECT}'/role/'${app_name}'/secret-id'
    local secretid=$(docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault write -f -format=json auth/approle_'${MC_PROJECT}'/role/'${app_name}'/secret-id | jq -r ".data.secret_id"')
    if [ ! $? = 0 ]
    then
        log "   failed. Leaving script."
        exit 1
    fi
    MC_LOGINDENT=$((MC_LOGINDENT-3))
    echo "$secretid"

}

function vault_get_apptoken() {

	local root_token=$1
    local role_id=$2
    local secret_id=$3

    MC_LOGINDENT=$((MC_LOGINDENT+3))
    log "Get apptoken with role_id='${role_id}' and secret_id=********"
    local apptoken=$(docker exec -i ${MC_PROJECT}_${MC_VAULTCONTAINER}_1 sh -c 'export VAULT_SKIP_VERIFY=1; export VAULT_TOKEN="'${root_token}'"; export VAULT_ADDR="'${MC_VAULTURL}':'${MC_VAULTPORT}'"; //home//appuser//app//vault write -format=json auth/approle_'${MC_PROJECT}'/login role_id='${role_id}' secret_id='${secret_id}' | jq -r ".auth.client_token"')
    MC_LOGINDENT=$((MC_LOGINDENT-3))
    echo "$apptoken"

}