function gitea_initial_setup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for gitea availability"
    gitea_wait_for_startup

    log "add open-id-connect provider"
    gitea_add_openid_provider

    log "create gitea testusers"
    gitea_create_users

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function gitea_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check gitea availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    cnt=0
    while ! docker exec -it ${MC_PROJECT}_gitea_1 sh -c "${cmd}" > /dev/null 2>&1; do
        ((cnt++))
        log "firststart_finished.flg not available. Wait 15s and try again ..."
        sleep 15s
        if [ $cnt -eq 21 ]
        then
            log "Failed to start gitea"
            exit 1
        fi
    done

    log "gitea setup finished."

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function gitea_create_users() {
    
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    local user_firstname="firstname"
    local user_lastname="lastname"
    local user_mailusername="mailusername"
    local user_maildomain="maildomain"
    local user_password="password"

    for u in "${users[@]}"
    do
        log "get values for user \"${u}\""
        local user_values=$(config_get_user_values "$u")

        IFS=';' read -ra kvparr <<< "$user_values"    #Convert string to array
        local cnt=0

        for kvp in ${kvparr[@]}
        do
            local param=$(echo $kvp | awk -F= '{print $1}')
            local value=$(echo $kvp | awk -F= '{print $2}')

            case $param in
                FIRSTNAME) 
                    user_firstname=$value
                    ;;
                LASTNAME) 
                    user_lastname=$value
                    ;;
                MAILUSERNAME)
                    if [ "${value}" == '${USERNAME}' ]; then value=$u; fi
                    user_mailusername=$value
                    ;;
                MAILDOMAIN) 
                    if [ "${value}" == '${MAILDOMAIN}' ]; then value=${MC_MAILDOMAIN}; fi
                    user_maildomain=$value
                    ;;
                PASSWORD)
                    if [ "${value}" == '${DEFAULTPASSWORD}' ]; then value=${MC_DEFAULTPASSWORD}; fi 
                    user_password=$value
                    ;;
                *) # Handles all unknown parameter 
                    log "   Ignoring unknown parameter \"$param\""
                    ;;
            esac
            shift
            ((cnt++))
        done
        gitea_write_user "${u}" "${user_firstname}" "${user_lastname}" "${user_mailusername}" "${user_maildomain}" "${user_password}"
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function gitea_add_openid_provider() {

    log "create OpenID Connect configuration"
    cmd="cd /home/appuser/app
        ./gitea -c /home/appuser/data/gitea.ini admin auth add-oauth --name gitea.${MC_PROJECT} --provider OpenIDConnect --key gitea.${MC_PROJECT} --secret 12345678-1234-abd-1234-0123456789ab --auto-discovery-url https://keycloak.dogchain.go/auth/realms/${MC_PROJECT}/.well-known/openid-configuration"
    docker exec -it ${MC_PROJECT}_gitea_1 sh -c "${cmd}" > /dev/null 2>&1

}

function gitea_write_user() {

    local user_username=$1    
    local user_firstname=$2
    local user_lastname=$3
    local user_mailusername=$4
    local user_maildomain=$5
    local user_password=$6

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create user in gitea"

    log "create user \"${user_username}\" with mail address "${user_mailusername}@${user_maildomain}" in gitea"
    
    cmd="cd /home/appuser/app
        ./gitea -c /home/appuser/data/gitea.ini admin create-user --username \"${user_username}\" --password ${user_password} --email ${user_mailusername}@${user_maildomain}"
    docker exec -it ${MC_PROJECT}_gitea_1 sh -c "${cmd}" > /dev/null 2>&1

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}