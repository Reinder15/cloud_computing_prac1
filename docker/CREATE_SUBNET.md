
# Docker Subnetten: Meerdere Netwerken Creëren en Beheren

## Waarom meerdere Docker subnetten?

Docker subnetten (networks) stellen je in staat om containers in geïsoleerde netwerksegmenten te plaatsen. Dit biedt verschillende voordelen:

- Containers in verschillende netwerken kunnen niet rechtstreeks met elkaar communiceren, wat ongewenste toegang voorkomt.
- Je kunt applicaties voor verschillende klanten in afzonderlijke netwerken isoleren.
- Scheid frontend, backend en database services in verschillende netwerken.
- Voer tests uit in een gescheiden netwerk zonder het productiesysteem te beïnvloeden.

## Hoe werkt dit?

Wanneer je een Docker network creëert, krijgt het een eigen subnetrange (bijv. 172.20.0.0/16). Containers in hetzelfde network kunnen met elkaar communiceren. Containers in verschillende networks kunnen NIET direkt met elkaar praten, tenzij je dit expliciet configureert via bridge netwerken.

---

## Praktijkvoorbeeld: Twee geïsoleerde subnetten met MySQL

### 1. Network interfaces controleren

```bash
ip a show
```

### 2. Twee subnetten creëren

```bash
docker network create network1
docker network create network2
```

### 3. Alle netwerken weergeven

```bash
docker network ls
```

### 4. Containers starten in network1

MySQL service en test container in network1:

```bash
docker run -itd --rm --network network1 \
    --name container1 \
    -v container1-data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=todos \
    mysql:8.0

docker run -itd --rm --network network1 --name test_container1 busybox
```

### 5. Containers starten in network2

MySQL service en test container in network2:

```bash
docker run -itd --rm --network network2 \
    --name container2 \
    -v container2-data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=todos \
    mysql:8.0

docker run -itd --rm --network network2 --name test_container2 busybox
```

### 6. Network configuratie inspecteren

**Network1 details:**
```bash
docker inspect network1
```

**Output:**
```json
"Containers": {
    "374588128fa5a2690dbee386efd0095a10a9acc30293c4e52113966c091f1e34": {
        "Name": "container1",
        "IPv4Address": "172.20.0.2/16"
    },
    "4884414c3e5c5a827a1868c34c41f0c325b1cd48247545776bff266abd2fd9cd": {
        "Name": "test_container1",
        "IPv4Address": "172.20.0.3/16"
    }
}
```

**Network2 details:**
```bash
docker inspect network2
```

**Output:**
```json
"Containers": {
    "5c0439012ae4f3257e5e9717d17c58715e20d3483889185455b2d7e0bf633122": {
        "Name": "test_container2",
        "IPv4Address": "172.21.0.3/16"
    },
    "bab13b9887bb5ebf8269bff0c2a3b427ffe75a851583ba25cd928ba7b1cc39d4": {
        "Name": "container2",
        "IPv4Address": "172.21.0.2/16"
    }
}
```

---

## Connectivitytests

### Test 1: Host kan beide netwerken bereiken

**Ping naar container in network2:**
```bash
ping 172.21.0.2
```

**Output:**
```
PING 172.21.0.2 (172.21.0.2) 56(84) bytes of data.
64 bytes from 172.21.0.2: icmp_seq=1 ttl=64 time=0.620 ms
64 bytes from 172.21.0.2: icmp_seq=2 ttl=64 time=0.060 ms
--- 172.21.0.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
```

**Ping naar container in network1:**
```bash
ping 172.20.0.2
```

**Output:**
```
PING 172.20.0.2 (172.20.0.2) 56(84) bytes of data.
64 bytes from 172.20.0.2: icmp_seq=1 ttl=64 time=0.100 ms
64 bytes from 172.20.0.2: icmp_seq=2 ttl=64 time=0.061 ms
--- 172.20.0.2 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss
```

### Test 2: Containers in hetzelfde network kunnen communiceren ✓

**Vanuit test_container1 (in network1):**
```bash
docker exec -it test_container1 sh
ping 172.20.0.2
```

**Output (SUCCES):**
```
PING 172.20.0.2 (172.20.0.2): 56 data bytes
64 bytes from 172.20.0.2: seq=0 ttl=64 time=0.371 ms
64 bytes from 172.20.0.2: seq=1 ttl=64 time=0.108 ms
3 packets transmitted, 3 packets received, 0% packet loss
```

### Test 3: Containers in verschillende netwerken KUNNEN NIET communiceren ✗

**Vanuit test_container1 (network1) naar test_container2 (network2):**
```bash
docker exec -it test_container1 sh
ping 172.21.0.3
```

**Output (GEFAALD - intentioneel):**
```
PING 172.21.0.3 (172.21.0.3): 56 data bytes
--- 172.21.0.3 ping statistics ---
4 packets transmitted, 0 packets received, 100% packet loss
```

**Vanuit test_container2 (network2) naar test_container1 (network1):**
```bash
docker exec -it test_container2 sh
ping 172.20.0.3
```

**Output (GEFAALD - intentioneel):**
```
PING 172.20.0.3 (172.20.0.3): 56 data bytes
--- 172.20.0.3 ping statistics ---
3 packets transmitted, 0 packets received, 100% packet loss
```

---

## Conclusie

Dit voorbeeld toont aan dat:
- ✓ Containers in hetzelfde network kunnen vrijelijk communiceren
- ✓ De host kan alle netwerken bereiken
- ✗ Containers in verschillende networks zijn standaard geïsoleerd
