function obazda_initial_setup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "wait for obazda availability"
    obazda_wait_for_startup

    log "create obazda testusers"
    obazda_create_users

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function obazda_wait_for_startup() {

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "check obazda availability by searching for firststart_finished.flg"
    cmd="ls /home/appuser/data/firststart_finished.flg"

    cnt=0
    while ! docker exec -it ${MC_PROJECT}_obazda_1 sh -c "${cmd}" > /dev/null 2>&1; do
        ((cnt++))
        log "firststart_finished.flg not available. Wait 15s and try again ..."
        sleep 15s
        if [ $cnt -eq 21 ]
        then
            log "Failed to start obazda"
            exit 1
        fi
    done

    log "obazda setup finished."

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function obazda_create_groups() {
     
    MC_LOGINDENT=$((MC_LOGINDENT+3))

    local group_description="description"
    local group_users="users"

    for g in "${groups[@]}"
    do
        log "get values for groups \"${g}\""
        local group_values=$(config_get_group_values "$g")

        IFS=';' read -ra kvparr <<< "$group_values"    #Convert string to array
        local cnt=0

        for kvp in ${kvparr[@]}
        do
            local param=$(echo $kvp | awk -F= '{print $1}')
            local value=$(echo $kvp | awk -F= '{print $2}')

            case $param in
                DESCRIPTION) 
                    group_description=$value
                    ;;
                USERS) 
                    group_users=$value
                    ;;
                *) # Handles all unknown parameter 
                    log "   Ignoring unknown parameter \"$param\""
                    ;;
            esac
            shift
            ((cnt++))
        done
        obazda_write_group "${g}" "${group_description}" "${group_users}"
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function obazda_write_group() {

    local group_groupname=$1
    local group_description=$2
    local group_users=$3

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create group in obazda"

    log "create group \"${group_groupname}\" with description "${description}" in obazda"
    
    #TODO: Integrate building one or multiple JSON files and put them into the obazda container. Please check keycloak.sh how to do that
    
    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function obazda_create_users() {
    
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
        obazda_write_user "${u}" "${user_firstname}" "${user_lastname}" "${user_mailusername}" "${user_maildomain}" "${user_password}"
    done

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

function obazda_write_user() {

    local user_username=$1    
    local user_firstname=$2
    local user_lastname=$3
    local user_mailusername=$4
    local user_maildomain=$5
    local user_password=$6

    MC_LOGINDENT=$((MC_LOGINDENT+3))

    log "Create user in obazda"

    log "create user \"${user_username}\" with mail address "${user_mailusername}@${user_maildomain}" in obazda"
    
    # cmd="cd /home/appuser/app
    #     ./gitea -c /home/appuser/data/gitea.ini admin create-user --username \"${user_username}\" --password ${user_password} --email ${user_mailusername}@${user_maildomain}"
    # docker exec -it ${MC_PROJECT}_gitea_1 sh -c "${cmd}" > /dev/null 2>&1

    MC_LOGINDENT=$((MC_LOGINDENT-3))
}

