#!/bin/bash
set -xe

source lib/logging.sh
source lib/common.sh

eval "$(go env)"

M3PATH="${GOPATH}/src/github.com/metal3-io"
BMOPATH="${M3PATH}/baremetal-operator"
CAPBMPATH="${M3PATH}/cluster-api-provider-baremetal"

function clone_repos() {
    mkdir -p ${M3PATH}
    if [ ! -d ${BMOPATH} ] ; then
        pushd ${M3PATH}
        git clone https://github.com/metal3-io/baremetal-operator.git
        popd
    fi
    pushd ${BMOPATH}
    git pull -r || true
    popd
    if [ ! -d ${CAPBMPATH} ] ; then
        pushd ${M3PATH}
        git clone https://github.com/metal3-io/cluster-api-provider-baremetal.git
        popd
    fi
    pushd ${CAPBMPATH}
    git pull -r || true
    popd
}

function configure_minikube() {
    minikube config set vm-driver kvm2
}

function launch_minikube() {
    minikube start
    # The interface doesn't appear in the minikube VM with --live,
    # so just attach it and make it reboot.
    sudo virsh attach-interface --domain minikube \
        --model virtio --source provisioning \
        --type network --config
    minikube stop
    minikube start
}

function launch_baremetal_operator() {
    pushd ${BMOPATH}
    make deploy
    popd
}


function make_bm_hosts() {
    while read name address user password mac; do
        go run ${BMOPATH}/cmd/make-bm-worker/main.go \
           -address "$address" \
           -password "$password" \
           -user "$user" \
           -boot-mac "$mac" \
           "$name"
    done
}

function apply_bm_hosts() {
    list_nodes | make_bm_hosts > bmhosts_crs.yaml
    kubectl apply -f bmhosts_crs.yaml -n metal3
}

#
# Launch the cluster-api controller manager in the metal3 namespace.
#
function launch_cluster_api() {
    pushd ${CAPBMPATH}
    make deploy
    popd
}

clone_repos
configure_minikube
launch_minikube
launch_baremetal_operator
apply_bm_hosts
launch_cluster_api
