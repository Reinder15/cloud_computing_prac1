#!/usr/bin/env bash

set -euo pipefail

TEST_ID="$(date +%s)"
NETWORK_NAME="multi-host-network-test-${TEST_ID}"
NETWORK_NAME_BY_ID="multi-host-network-id-test-${TEST_ID}"
SUBNET="10.10.36.0/24"
GATEWAY="10.10.36.1"
STATIC_IP="10.10.36.122"

CONTAINER1="net-test-container1-${TEST_ID}"
CONTAINER2="net-test-container2-${TEST_ID}"

log() {
	echo "[docker-network-test] $*"
}

cleanup() {
	set +e
	docker rm -f "${CONTAINER1}" "${CONTAINER2}" >/dev/null 2>&1
	docker network rm "${NETWORK_NAME}" "${NETWORK_NAME_BY_ID}" >/dev/null 2>&1
}

trap cleanup EXIT

if ! command -v docker >/dev/null 2>&1; then
	echo "Docker CLI not found in PATH." >&2
	exit 1
fi

if ! docker info >/dev/null 2>&1; then
	echo "Docker daemon is not reachable. Start Docker and retry." >&2
	exit 1
fi

log "Listing networks (docker network ls)"
docker network ls

log "Creating test network ${NETWORK_NAME}"
docker network create \
	--driver bridge \
	--subnet "${SUBNET}" \
	--gateway "${GATEWAY}" \
	--label docker-networking-script-test=true \
	"${NETWORK_NAME}" >/dev/null

log "Starting two test containers"
docker run -d --name "${CONTAINER1}" alpine:3.20 sleep 600 >/dev/null
docker run -d --name "${CONTAINER2}" alpine:3.20 sleep 600 >/dev/null

log "Connecting ${CONTAINER1} to ${NETWORK_NAME} (docker network connect)"
docker network connect "${NETWORK_NAME}" "${CONTAINER1}"

log "Connecting ${CONTAINER2} with static IP and aliases"
docker network connect \
	--ip "${STATIC_IP}" \
	--alias db \
	--alias mysql \
	"${NETWORK_NAME}" \
	"${CONTAINER2}"

log "Validating static IP and aliases for ${CONTAINER2}"
docker inspect "${CONTAINER2}" \
	--format 'IP={{(index .NetworkSettings.Networks "'"${NETWORK_NAME}"'" ).IPAddress}} Aliases={{(index .NetworkSettings.Networks "'"${NETWORK_NAME}"'" ).Aliases}}'

log "Disconnecting ${CONTAINER1} from ${NETWORK_NAME} (docker network disconnect)"
docker network disconnect "${NETWORK_NAME}" "${CONTAINER1}"

log "Removing network by name (docker network rm <name>)"
docker network disconnect "${NETWORK_NAME}" "${CONTAINER2}" >/dev/null
docker network rm "${NETWORK_NAME}"

log "Creating second network to test remove-by-id"
docker network create \
	--driver bridge \
	--label docker-networking-script-test=true \
	"${NETWORK_NAME_BY_ID}" >/dev/null

NETWORK_ID="$(docker network inspect -f '{{.Id}}' "${NETWORK_NAME_BY_ID}")"
log "Removing network by id (docker network rm <id>)"
docker network rm "${NETWORK_ID}"

log "Creating test network to demonstrate safe prune"
docker network create \
	--driver bridge \
	--label docker-networking-script-test=true \
	"docker-network-prune-test-${TEST_ID}" >/dev/null

log "Pruning only script-labeled networks"
docker network prune --force --filter label=docker-networking-script-test=true

log "All docker network command tests completed successfully."