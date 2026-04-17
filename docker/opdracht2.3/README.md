
### Reverse Proxy

Tutorial: https://doc.traefik.io/traefik/getting-started/docker/

Stappen:
1. Start Traefik met docker-compose en configureer dashboard
   Zie [docker-compose.yml](./docker-compose.yml) voor configuratie
   Zie [TRAEFIK_DASHBOARD_RUNNING](scrn/1.TRAEFIK_DASHBOARD_RUNNING.png)
2. Deploy een applicatie
   Zie [whoami.yml](./whoami.yml) voor configuratie
   Zie [TRAEFIK_WHOAMI_RUNNING](scrn/2.TRAEFIK_WHOAMI_RUNNING.png)

**Definitie van een reverse proxy:**
Een reverse proxy is een server die vaak tussen de client en een of meerdere backend servers staat. De reverse proxy ontvangt alle requests van de clients en stuurt deze door naar de juiste backend server. Het zorgt ervoor dat de backend servers niet direct toegankelijk zijn voor de clients en kan ook extra functionaliteiten bieden zoals load balancing, SSL-terminatie, caching en beveiliging.

### Load Balancing

Tutorial: https://medium.com/@benjaminpowell24/how-to-implement-a-load-balancer-with-nginx-and-docker-1e2d68c676b5

Stappen:
1. Een kleine Node app maken die een string teruggeeft.
   - Node + npm geinstalleerd.
   - `npm init` uitgevoerd + `npm install express` om express te installeren.
   - Zie [index.js](/docker/opdracht2.3/Load_balancer/index.js) voor de code
   - Zie [Dockerfile](/docker/opdracht2.3/Load_balancer/Dockerfile) voor de Dockerfile
   - Zie [NODE_APP_RUNNING](scrn/1.SERVER_APP_1_READY.png)
2. Een 2e server klaar zetten
   - `cp -r server-app-1 server-app-2`
   - port en naam gewijzigd, zie [index.js](/docker/opdracht2.3/Load_balancer/server-app-2/index.js) en [Dockerfile](/docker/opdracht2.3/Load_balancer/server-app-2/Dockerfile)
   - Zie [NODE_APP_2_RUNNING](scrn/2.SERVER_APP_2_READY.png)
3. Load balancer klaar zetten
   - Nginx image gebruiken
   - Configuratie bestand maken, zie [server.conf](/docker/opdracht2.3/Load_balancer/server.conf)
   - Zie [DOCKERFILE_NGINX](/docker/opdracht2.3/Load_balancer/Dockerfile_nginx) voor de Dockerfile
   - Zie [NGINX_READY](scrn/3.NGINX_READY.png)
4. Samen starten met docker-compose
   - Zie [docker-compose.yml](./Load_balancer/docker-compose.yml) voor de configuratie
5. Testen
   - `curl http://localhost:80/v1/` meerdere keren uitvoeren, je ziet afwisselend "Hello from server 1" en "Hello from server 2".
   - Zie [LOAD_BALANCER_WORKING](scrn/4.LOAD_BALANCER_WORKING.png)

