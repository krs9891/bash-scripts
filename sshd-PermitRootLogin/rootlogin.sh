#!/bin/bash

DEFAULT_POLICY="without-password"

show_help() {
    echo
    printf "This script configures SSHD's PermitRootLogin setting according to user preference.\n"
    printf "By default, if no option is provided, 'PermitRootLogin' will be set to 'without-password'.\n"
    printf "This setting can by changed by altering DEFAULT_POLICY variable in the script.\n\n"
    printf "Usage: %s [OPTION]\n\n" "$0"
    printf "Options:\n"
    printf "  %-25s %s\n" "-h, --help" "Show this help message and exit"
    printf "  %-25s %s\n" "-p, --permit" "Permit root login with any authentication method (least secure)"
    printf "  %-25s %s\n" "-w, --without-password" "Permit root login but prohibit password authentication (use public keys, etc.)"
    printf "  %-25s %s\n" "-f, --forced-commands" "Permit root login only with SSH keys and forced commands"
    printf "  %-25s %s\n" "-n, --no" "Completely deny root login over SSH (most secure)"
    printf "  %-25s %s\n" "-c, --comment" "Comment out the 'PermitRootLogin' line in the configuration file"
}

print_color(){
    NC='\033[0m'
    
    case $1 in
        "green") COLOR='\033[0;32m' ;;
        "red") COLOR='\033[0;31m' ;;
        "*") COLOR='\033[0m' ;;
    esac

    echo -e "${COLOR} $2 ${NC}"
}

change_permit_root_login() {
    local setting=$1

    CONFIG_FILE='/etc/ssh/sshd_config'
    BACKUP_FILE="${CONFIG_FILE}.backup"
    TEMP_FILE="${CONFIG_FILE}.temp"

    sudo cp $CONFIG_FILE $BACKUP_FILE

    if grep -qE '^[[:space:]]*#?[[:space:]]*PermitRootLogin' $CONFIG_FILE; then
        sudo awk -v setting="$setting" '
            /^#?PermitRootLogin/ {$0="PermitRootLogin "setting}
            {print}
        ' $CONFIG_FILE | sudo tee $TEMP_FILE > /dev/null
        sudo mv $TEMP_FILE $CONFIG_FILE
    else
        echo "PermitRootLogin $setting" | sudo tee -a $CONFIG_FILE > /dev/null
    fi

    finalize_sshd_config_change "$setting" "$CONFIG_FILE" "$BACKUP_FILE"
}

comment_permit_root_login() {
    CONFIG_FILE='/etc/ssh/sshd_config'
    BACKUP_FILE="${CONFIG_FILE}.backup"
    TEMP_FILE="${CONFIG_FILE}.temp"

    sudo cp $CONFIG_FILE $BACKUP_FILE

    if grep -qE '^[[:space:]]*#?[[:space:]]*PermitRootLogin' $CONFIG_FILE; then
        sudo awk '
            /^#?PermitRootLogin/ {$0="#"$0}
            {print}
        ' $CONFIG_FILE | sudo tee $TEMP_FILE > /dev/null
        sudo mv $TEMP_FILE $CONFIG_FILE
    fi

    finalize_sshd_config_change "commented out" "$CONFIG_FILE" "$BACKUP_FILE"
}

cleanup() {
    sudo rm -f "$BACKUP_FILE"
}

trap cleanup EXIT

finalize_sshd_config_change() {
    local setting=$1
    local CONFIG_FILE=$2
    local BACKUP_FILE=$3

    if [ "$setting" = "commented out" ]; then
        if grep -q "^#PermitRootLogin" $CONFIG_FILE; then
            sudo systemctl restart sshd
            print_color "green" "PermitRootLogin setting commented out and sshd service restarted."
            check_service_status "sshd"
        else
            sudo cp $BACKUP_FILE $CONFIG_FILE
            print_color "red" "Failed to update SSHD configuration. Original configuration restored."
            exit 1
        fi
    else
        if grep -q "^PermitRootLogin $setting" $CONFIG_FILE; then
            sudo systemctl restart sshd
            print_color "green" "sshd configuration updated to 'PermitRootLogin $setting' and service restarted."
            check_service_status "sshd"
        else
            sudo cp $BACKUP_FILE $CONFIG_FILE
            print_color "red" "Failed to update SSHD configuration. Original configuration restored."
            exit 1
        fi
    fi
}

check_service_status(){
    is_service_active=$(systemctl is-active $1)

    if [ $is_service_active = "active" ]
    then
        print_color "green" "$1 service is active"
    else
        print_color "red" "$1 service is not active"
        exit 1
    fi
}

opt_processed=false

while (( "$#" )); do
    opt_processed=true
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -p|--permit)
            change_permit_root_login "yes"
            shift
            ;;
        -w|--without-password)
            change_permit_root_login "without-password"
            shift
            ;;
        -f|--forced-commands)
            change_permit_root_login "forced-commands-only"
            shift
            ;;
        -n|--no)
            change_permit_root_login "no"
            shift
            ;;
        -c|--comment)
            comment_permit_root_login
            shift
            ;;
        *) # unknown option
            print_color "red" "Invalid option: $1" 1>&2
            show_help
            exit 1
            ;;
    esac
done

if ! $opt_processed ; then
    change_permit_root_login $DEFAULT_POLICY
fi

exit 0
