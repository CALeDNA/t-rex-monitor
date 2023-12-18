#! /bin/bash


DASHBOARD=/var/lib/grafana/dashboards/overview.json
datasources=datasources.yaml
DATASOURCE=/etc/grafana/provisioning/datasources/datasources.yaml
USER=ubuntu
START=0
NAME="chunk"
VMNUMBER=0
while getopts "h:u:s:n:b:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        n) NAME="$OPTARG"
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
    esac
done

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost
./grafana-pssh.sh -h tmphost -u $USER

counter=$VMNUMBER
if [ $START -gt 0 ]; then
    # use tmphost file
    hostnames=$(cat tmphost)
    for line in $hostnames
    do
        address=$(ssh -G $line | awk '/^hostname / { print $2 }')
        echo "  - name: $line" >> $datasources
        echo "    type: prometheus" >> $datasources
        echo "    url: http://$address:9090" >> $datasources
        echo "    uid: $line" >> $datasources
        echo "    readOnly: false" >> $datasources
        echo "    editable: true" >> $datasources
        echo "" >> $datasources
    done
    sudo cat $datasources >> $DATASOURCE
    rm $datasources
else
    hostnames=$(cat $HOSTNAME)
    echo "apiVersion: 1" >> $datasources
    echo "datasources:" >> $datasources
    for line in $hostnames
    do
        address=$(ssh -G $line | awk '/^hostname / { print $2 }')
        echo "  - name: $line" >> $datasources
        echo "    type: prometheus" >> $datasources
        echo "    url: http://$address:9090" >> $datasources
        echo "    uid: $line" >> $datasources
        echo "    readOnly: false" >> $datasources
        echo "    editable: true" >> $datasources
        echo "" >> $datasources
    done
    sudo mv $datasources $DATASOURCE
fi

rm tmphost $datasources

#update dashboard panels reflecting datasources.yaml changes
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE

sudo systemctl restart grafana-server
