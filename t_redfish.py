#!/usr/bin/env python3
import requests
from requests.auth import HTTPBasicAuth
import json
import argparse
from pprint import pprint

# URL = '/redfish/v1/Systems/096bd390-29a4-40d2-8fac-9b72ac80562a'


def check_redfish_api(node):
    di = node['driver_info']
    pprint(di)
    url = di['address'].replace('redfish+','')
    auth=HTTPBasicAuth(di['username'], di['password'])
    r = requests.get(url, auth=auth)
    ret = json.loads(r.content)
    pprint(ret)


def main(args):
    with open(args.inventory_fn, 'r') as fi:
        inv = json.load(fi)
        rf_nodes = filter(lambda a: a['driver'] == 'redfish', inv['nodes'])
        for node in rf_nodes:
            check_redfish_api(node)


if __name__  == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-i', dest='inventory_fn',
            help='Specify inventory file ironic_nodes.json',
            required=True)
    args = parser.parse_args()
    main(args)
