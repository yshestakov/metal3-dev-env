#!/bin/bash

cat <<EOF |while read CMD 
ip link del ironicendpoint type veth peer name ironic-peer
ip link set down provisioning
brctl delbr provisioning
ip link add name eth2 type dummy
EOF
do
	sudo su -l -c "minikube ssh sudo $CMD" stack
done

