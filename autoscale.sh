#! /bin/bash


JS2AUTOSCALING="/home/ubuntu/t-rex-monitor/js2-autoscaling.sh"
CONFIG="/home/ubuntu/crux/crux/vars/crux_vars.sh"
SETUP_CONFIG="/home/ubuntu/t-rex-monitor/vm_vars.sh"
QUEUES=("/etc/ben/queue/qc.ini" "/etc/ben/queue/assign.ini" "/etc/ben/queue/ecopcr.ini" "/etc/ben/queue/blast.ini" "/etc/ben/queue/ac.ini" "/etc/ben/queue/newick.ini" "/etc/ben/queue/tronko.ini")

cd /home/ubuntu/t-rex-monitor

# Iterate over $QUEUES list
for queue in "${QUEUES[@]}"; do
  # run if queue exists
  if [ -f "$queue" ]; then
    # get server socket file
    base_path="${queue##*/}"
    # Remove everything after and including the last dot
    base_name="${base_path%.*}"
    # Replace slashes with dashes
    # new_path="${queue//\//-}"
    # Combine base name and modified path
    server="/tmp/ben-${base_name}"

    # check for pending jobs
    if grep -q "type = pending" "$queue"; then
        # scale up
        # js2-autoscaling.sh handles if it should scale up
        $JS2AUTOSCALING -b $server -c $SETUP_CONFIG
    else
        # scale down
        # js2-autoscaling.sh handles if it should scale down
        $JS2AUTOSCALING -b $server -c $SETUP_CONFIG -d
    fi
  fi
done