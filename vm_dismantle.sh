#! /bin/bash

OS_USERNAME=""
JSCRED=""
HOSTNAME=""
NAME=""
USER="ubuntu"
BENPATH="/etc/ben/ben"
while getopts "j:h:m:e:c:d:D:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
        c) SSHCONFIG="$OPTARG"
        ;;
        d) DATASOURCE="$OPTARG"
        ;;
        D) DASHBOARD="$OPTARG"
        ;;
    esac
done

BASEDIR="$HOME/t-rex-monitor"

mv $HOSTNAME $BASEDIR/main
cd $BASEDIR/main

# remove VM from ben server
$BENPATH scale -n 0 $NAME -s $BENSERVER # just in case
$BENPATH kill $NAME -s $BENSERVER

# remove host from known_hosts
address=$(ssh -G "$NAME" | awk '/^hostname / {print $2}')
ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "$address"

# delete VM
./dismantle_instance.sh -j $JSCRED -h $HOSTNAME -m $NAME -c $SSHCONFIG -d $DATASOURCE


mv $HOSTNAME $BASEDIR
cd $BASEDIR/grafana/main
# update grafana dashboard
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE

# update ben panels in grafana
sudo python3 ben-dashboard-mod.py --dashboard $DASHBOARD

sudo systemctl restart grafana-server.service