#!/usr/bin/env bash

set -xe

# shellcheck disable=SC1091
source lib/logging.sh
# shellcheck disable=SC1091
source lib/common.sh
# shellcheck disable=SC1091
source lib/network.sh

if [ "$MANAGE_PRO_BRIDGE" == "y" ]; then
     # Adding an IP address in the libvirt definition for this network results in
     # dnsmasq being run, we don't want that as we have our own dnsmasq, so set
     # the IP address here.
     # Create a veth iterface peer.
     ip link list ironicendpoint || \
	     sudo ip link add ironicendpoint type veth peer name ironic-peer 
     # Create provisioning bridge.
     ip link list provisioning || \
	     sudo brctl addbr provisioning
     # sudo ifconfig provisioning 172.22.0.1 netmask 255.255.255.0 up
     # Use ip command. ifconfig commands are deprecated now.
     sudo ip link set provisioning up
     if [[ "${PROVISIONING_IPV6}" == "true" ]]; then
        sudo ip -6 addr add "$PROVISIONING_IP"/"$PROVISIONING_CIDR" dev ironicendpoint
      else
        sudo ip addr add dev ironicendpoint "$PROVISIONING_IP"/"$PROVISIONING_CIDR" || true
     fi
     if [ -x /usr/bin/ovs-vsctl ] ; then
	     # OpenVSwitch
	     sudo /usr/bin/ovs-vsctl del-port provisioning ironic-peer || true
	     sudo /usr/bin/ovs-vsctl add-port provisioning ironic-peer
     else
	     # legacy bridge-utils
	     sudo brctl delif provisioning ironic-peer || true
	     sudo brctl addif provisioning ironic-peer
     fi
     sudo ip link set ironicendpoint up
     sudo ip link set ironic-peer up
     # Need to pass the provision interface for bare metal
     if [ "$PRO_IF" ]; then
       if [ -x /usr/bin/ovs-vsctl ] ; then
           sudo ovs-vsctl add-port provisioning "$PRO_IF"
       else
           sudo brctl addif provisioning "$PRO_IF"
       fi
     fi
 fi

 if [ "$MANAGE_INT_BRIDGE" == "y" ]; then
     # Create the baremetal bridge
     if ! [[  $(ip a show baremetal) ]]; then
       sudo brctl addbr baremetal
       # sudo ifconfig baremetal 192.168.111.1 netmask 255.255.255.0 up
       # Use ip command. ifconfig commands are deprecated now.
       if [[ -n "${EXTERNAL_SUBNET_V4_HOST}" ]]; then
         sudo ip addr add dev baremetal "${EXTERNAL_SUBNET_V4_HOST}/${EXTERNAL_SUBNET_V4_PREFIX}"
       fi
       if [[ -n "${EXTERNAL_SUBNET_V6_HOST}" ]]; then
         sudo ip addr add dev baremetal "${EXTERNAL_SUBNET_V6_HOST}/${EXTERNAL_SUBNET_V6_PREFIX}"
       fi
       sudo ip link set baremetal up
     fi

     # Add the internal interface to it if requests, this may also be the interface providing
     # external access so we need to make sure we maintain dhcp config if its available
     if [ "$INT_IF" ]; then
       sudo brctl addif "$INT_IF"
     fi
 fi

 # restart the libvirt network so it applies an ip to the bridge
 if [ "$MANAGE_BR_BRIDGE" == "y" ] ; then
     sudo virsh net-destroy baremetal
     sudo virsh net-start baremetal
     if [ "$INT_IF" ]; then #Need to bring UP the NIC after destroying the libvirt network
         sudo ifup "$INT_IF"
     fi
 fi
