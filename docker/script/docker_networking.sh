#! /bin/bash

docker network ls 

docker network connect multi-host-network container

docker network connect --IP 10.10.36.122 multi-host-network container

docker network connect --alias db --alias mysql multi-host-network container2

docker network disconnect multi-host-network container1

docker network rm network_name

docker network rm 3695c422697f network_name

docker network prune