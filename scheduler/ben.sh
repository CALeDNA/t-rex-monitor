#! /bin/bash

USER="ubuntu"
REMOTE_PATH=/etc/ben/ben
START=0
NODES=4
VMNUMBER=0
while getopts "h:s:n:m:u:e:b:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        n) NODES="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
    esac
done

declare -A SERVER_MAP

SERVER_MAP=(
    ["/tmp/ben-ecopcr"]=("/tmp/ben-blast")
    ["/tmp/ben-blast"]=("/tmp/ben-ac")
    ["/tmp/ben-ac"]=("/tmp/ben-newick")
    ["/tmp/ben-newick"]=("/tmp/ben-tronko")
    ["/tmp/ben-qc"]=("/tmp/ben-assign" "/tmp/ben-assignxl")
    ["/tmp/ben-assign"]=("/tmp/ben-assignxl")
    ["/tmp/ben-assignxl"]=("/tmp/ben-assign")
)

# make tmp hosts file for parallel-ssh script. only lines after $START
sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

# setup ben in client VMs
./ben-pssh.sh -h tmphost

if [ $START -gt 0 ]; then
    hostnames=$(cat tmphost)
else
    hostnames=$(cat $HOSTNAME)
fi

counter=$VMNUMBER
for line in $hostnames
do
    counter=$(printf '%02d' $counter)
    host="$NAME$counter"
    /etc/ben/ben client -r $host -n $NODES --remote-path $REMOTE_PATH -s $BENSERVER --remote-socket $BENSERVER -d
    if [[ -v SERVER_MAP[${BENSERVER}] ]]; then
        # add socket connections to queue jobs
        for socket in "${SERVER_MAP[${BENSERVER}]}"; do
            /etc/ben/ben client -r "$host" -n 0 --remote-path "$REMOTE_PATH" -s "$socket" --remote-socket "$socket" -d
        done
    fi
    counter=$(( 10#$counter + 1 ))
done

rm tmphost