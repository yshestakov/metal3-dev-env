#!/bin/bash
ip link del ironicendpoint type veth peer name ironic-peer
ip link set down provisioning
brctl delbr provisioning

ip link list eth2 >/dev/null || ip link add name eth2 type dummy

docker ps  |awk '$1 ~ /[0-9a-f]/ {print $1}' |xargs -n1 docker stop
docker ps -a |awk '$1 ~ /[0-9a-f]/ {print $1}' |xargs -n1 docker rm
