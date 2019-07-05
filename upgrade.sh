#!/usr/bin/env bash
date
export PATH=$PATH:/usr/sbin
echo "PATH: $PATH"

# Fetch new nsx-lcp bundle
rm -rf /tmp/nsx*
# wget $1 -P /tmp/
curl $1 -o /tmp/${1##*/}
tar xvC /tmp/ -f /tmp/${1##*/}

# pre-upgrade
filter_ovs_ifaces() {
    while [ $# -gt 0 ]; do
        case $1 in
            -4|-6|-1|-d|-nw|-q|-v|-w|-n|-S|-T|-P|-N|--no-pid)
                ;;
            -e|-p|-s|-g|-D|-cf|-lf|-pf|-sf)
                if [ -z "$2" ]; then
                    echo "Option $1 requires an argument" >&2
                    break
                fi
                shift
                ;;
            *)
                if ovs-vsctl --columns=name --data=bare --no-heading --no-wait --timeout=5 list port | egrep "(\s|^)$1(\s|$)" >/dev/null 2>/dev/null; then
                    ifaces[${#ifaces[@]}]="$1 $(ovs-vsctl list-ports $1 2>/dev/null | tr '\n' ' ')"
                fi
                ;;
        esac
        shift
    done
}
ifaces=
while read _dhclient line; do
    filter_ovs_ifaces $line
done < <(ps -C dhclient -o cmd h)
if [ -f /opt/vmware/bin/netcpa.sh ]; then
   /etc/init.d/nsx-agent stop
fi
kill `ps hf -opid,cmd -C tcpdump | grep span-0 | awk '{print $1}'`

# Hack for DGo to Eq, remove in Eq to Eq.Next
rpm -evv --noscripts --nodeps nsx-netcpa 2>&1
if [ -f /opt/vmware/bin/netcpa.sh ]; then
   rm /opt/vmware/bin/netcpa.sh
fi
ps -ef | grep /usr/bin/netcpa | grep -v grep | awk '{print $2}' | xargs -r kill -s 9 || :

#upgrade
rpm -Uvh --replacepkgs /tmp/nsx-lcp-rhel76_x86_64/nsx*.rpm 2>&1
rpm -Uvh --replacepkgs /tmp/nsx-lcp-rhel76_x86_64/openvswitch*.rpm 2>&1
rpm -Uvh --replacepkgs /tmp/nsx-lcp-rhel76_x86_64/kmod-openvswitch*.rpm 2>&1

# post-upgrade
ovs-appctl dpctl/flush-conntrack
if [ -e /sys/module/openvswitch ]; then
   LOADED_SRCVERSION=`cat /sys/module/openvswitch/srcversion 2>/dev/null`
   LOADED_VERSION=`cat /sys/module/openvswitch/version 2>/dev/null`
elif [ -e /sys/module/openvswitch_mod ]; then
   LOADED_SRCVERSION=`cat /sys/module/openvswitch_mod/srcversion 2>/dev/null`
   LOADED_VERSION=`cat /sys/module/openvswitch_mod/version 2>/dev/null`
fi
SRCVERSION=`modinfo -F srcversion openvswitch 2>/dev/null`
VERSION=`modinfo -F version openvswitch 2>/dev/null`
if [ -n "${LOADED_SRCVERSION}" ] && [ -n "${SRCVERSION}" ] && \
   [ "${SRCVERSION}" != "${LOADED_SRCVERSION}" ]; then
   service openvswitch force-reload-kmod
else
   service openvswitch restart
fi

# Check status of OVS services
interval=5
((end_time=${SECONDS}+30))
OVS_PID_FILE="/var/run/openvswitch/ovs-vswitchd.pid"
OVSDB_PID_FILE="/var/run/openvswitch/ovsdb-server.pid"
STATUS=1
while ((${SECONDS} < ${end_time}))
do
    if [[ (-f $OVS_PID_FILE) && (-f $OVSDB_PID_FILE) ]];
    then
        STATUS=0
        break
    fi
    sleep ${interval}
done

if [[ "$STATUS" -eq 1 ]];
then
    echo Failed to restart OVS services.
    echo Upgrade failed.
    exit 1
fi

for iface_str in "${ifaces[@]}"; do
    echo Restoring interface: $iface_str
    read iface ports <<< $iface_str
    ifdown $iface && ifup $iface
    for port in $ports; do
        ovs-vsctl list-ports $iface | egrep "(\s|^)$port(\s|$)" >/dev/null 2>/dev/null && continue
        if [ -f /etc/sysconfig/network-scripts/ifcfg-$port ]; then
            echo Bringing up port: $port
            ifup $port
        else
            echo Adding port: $port
            ovs-vsctl --timeout=5 add-port $iface $port
        fi
    done
done

/etc/init.d/nsx-mpa restart
/etc/init.d/nsx-sfhc restart
rm -rf /tmp/nsx*
echo Upgrade completed.
exit 0
