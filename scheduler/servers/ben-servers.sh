#! /bin/bash

declare -A SERVER_MAP

USER="ubuntu"
REMOTE_PATH=/etc/ben/ben
HOSTNAME="/home/ubuntu/t-rex-monitor/hostnames"

SERVER_MAP=(
    ["/tmp/ben-ecopcr"]="/tmp/ben-blast"
    ["/tmp/ben-blast"]="/tmp/ben-ac"
    ["/tmp/ben-ac"]="/tmp/ben-newick"
    ["/tmp/ben-newick"]="/tmp/ben-tronko"
    ["/tmp/ben-qc"]="/tmp/ben-assign"
)

BENNAME=$1
BENSERVER=$2

# Check if the file exists and is readable
if [ -r "$HOSTNAME" ]; then
    while IFS= read -r host; do
        # rm all running containers in $host
        # and rm old socket file
        if [[ $host == "$BENNAME"* ]]; then
            ssh -n "$host" "docker ps -a | grep '$BENNAME' | awk '{ print \$1 }' | xargs -r docker rm -f"
            ssh -n "$host" "rm $BENSERVER"
        fi
    done < "$HOSTNAME"
else
    echo "The file $HOSTNAME does not exist or is not readable."
fi


/etc/ben/ben server --snapshot /etc/ben/queue/$BENNAME.ini -s $BENSERVER -d

/etc/ben/ben add -i /etc/ben/queue/$BENNAME.ini -s $BENSERVER


# Add client VM's
if [ -r "$HOSTNAME" ]; then
    while IFS= read -r host; do
        if [[ $host == *"$BENNAME"* ]]; then
            /etc/ben/ben client -r $host -n 1 --remote-path $REMOTE_PATH -s $BENSERVER --remote-socket $BENSERVER -d
            if [[ -v SERVER_MAP[${BENSERVER}] ]]; then
                # Add second socket connection if needed
                BENSERVERSECOND="${SERVER_MAP[${BENSERVER}]}"
                # rm old socket file
                ssh -n "$host" "rm $BENSERVERSECOND"
                /etc/ben/ben client -r $host -n 0 --remote-path $REMOTE_PATH -s $BENSERVERSECOND --remote-socket $BENSERVERSECOND -d
            fi
        fi
    done < "$HOSTNAME"
else
    echo "The file $HOSTNAME does not exist or is not readable."
fi