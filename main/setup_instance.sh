#!/bin/bash


USER=""
FLAVOR=""
IMAGE=""
PRIVATEKEY=""
JSCRED=""
NUMINSTANCES=0
SECURITY=""
VOLUME=""
VMNAME="chunk"
VMNUMBER=0
SETUP_CONFIG="/home/ubuntu/t-rex-monitor/vm_vars.sh"
while getopts "u:f:i:k:j:n:m:b:s:w:v:c:" opt; do
    case $opt in
        u) USER="$OPTARG"
        ;;
        f) FLAVOR="$OPTARG"
        ;;
        i) IMAGE="$OPTARG"
        ;;
        k) PRIVATEKEY="$OPTARG"
        ;;
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        m) VMNAME="$OPTARG"
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
        s) SECURITY="$OPTARG"
        ;;
        w) NETWORK="$OPTARG"
        ;;
        v) VOLUME="$OPTARG"
        ;;
        c) SSHCONFIG="$OPTARG" # SSH config file: $HOME/.ssh/config
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${USER} && ! -z ${FLAVOR} && ! -z ${IMAGE} && ! -z ${PRIVATEKEY} && ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${SECURITY} && ! -z ${NETWORK} && ! -z ${SSHCONFIG} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -f -i -k -j -n -w -c and -s"
  echo ""
  exit
fi

START=$VMNUMBER
END=$(( VMNUMBER + NUMINSTANCES))

source $JSCRED
source $SETUP_CONFIG


# create and start an instance
echo "create VMs"
for (( c=$START; c<$END; c++ ))
do
    chunk=$(printf '%02d' "$c")
    if [[ ! -z ${VOLUME} ]]
        then
            echo "creating VM with ${VOLUME}GB root disk"
            # create an instance
            openstack server create ${VMNAME}${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${PRIVATEKEY} \
            --security-group ${SECURITY} \
            --nic net-id=${NETWORK} \
            --boot-from-volume ${VOLUME} \
            --wait
        else
            echo "creating VM with default root disk size"
            # create an instance
            openstack server create ${VMNAME}${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${PRIVATEKEY} \
            --security-group ${SECURITY} \
            --nic net-id=${NETWORK} \
            --wait
    fi
done

echo "create and add floating ip's"
for (( c=$START; c<$END; c++ ))
do
    chunk=$(printf '%02d' "$c")
    # create an IP address and save it
    ip_address=$(openstack floating ip create -f json public | jq '.floating_ip_address' | tr -d '"')
    echo $ip_address
    # add ip to instance
    openstack server add floating ip ${VMNAME}${chunk} ${ip_address}

    echo "Host $VMNAME$chunk" >> $SSHCONFIG
    echo "HostName $ip_address" >> $SSHCONFIG
    echo "User $USER" >> $SSHCONFIG
    echo "PubKeyAuthentication yes" >> $SSHCONFIG
    echo "IdentityFile /home/$USER/.ssh/$PRIVATEKEY" >> $SSHCONFIG
    echo "IdentitiesOnly yes" >> $SSHCONFIG
    echo "StrictHostKeyChecking no" >> $SSHCONFIG
    echo "" >> $SSHCONFIG

    echo $VMNAME$chunk >> hostnames
    
    # Wait up to 5 minutes for SSH to be ready
    echo "Waiting for SSH to be ready on $VMNAME$chunk..."
    start_time=$(date +%s)
    while :
    do
        current_time=$(date +%s)
        elapsed=$(( current_time - start_time ))

        if [[ $elapsed -ge 300 ]]; then
            echo "Timeout: SSH not ready after 5 minutes on $VMNAME$chunk."
            echo "Deleting server $VMNAME$chunk..."
            ./dismantle_instance.sh -j $JSCRED -h hostnames -m $VMNAME$chunk -c $SSHCONFIG -d $DATASOURCE
            # del ip in case it wasn't attached
            openstack server remove floating ip $VMNAME$chunk $ip_address
            break
        fi

        if ssh -i /home/$USER/.ssh/$PRIVATEKEY -o ConnectTimeout=5 -o StrictHostKeyChecking=no $USER@$ip_address echo "SSH is up" > /dev/null 2>&1; then
            echo "SSH is ready on $VMNAME$chunk."
            break
        else
            echo "Still waiting for SSH on $VMNAME$chunk..."
            sleep 5
        fi
    done
done
