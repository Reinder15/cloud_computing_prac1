#Images op volgorde met nummering.
#Video voor bewijs van persistant storage

https://docs.docker.com/engine/install/ubuntu/

sudo docker run -dp 10.24.38.115:3000:3000 getting-started

docker run -dp 10.24.38.115:3000:3000 --mount type=volume,src=todo-db,target=/etc/todos getting-started

docker run -dp 10.24.38.115:3000:3000 \
    -w /app --mount type=bind,src=.,target=/app \
    node:24-alpine \
    sh -c "npm install && npm run dev"

docker run -d \
    --name todo-mysql \
    --network todo-app --network-alias mysql \
    -v todo-mysql-data:/var/lib/mysql \
    -e MYSQL_ROOT_PASSWORD=secret \
    -e MYSQL_DATABASE=todos \
    mysql:8.0


docker exec -it a85a78ea7a9f mysql -u root -p

docker run -dp 10.24.38.115:3000:3000 \
  -w /app -v ".:/app" \
  --network todo-app \
  -e MYSQL_HOST=mysql \
  -e MYSQL_USER=root \
  -e MYSQL_PASSWORD=secret \
  -e MYSQL_DB=todos \
  node:24-alpine \
  sh -c "npm install && npm run dev"

docker exec -it a85a78ea7a9f mysql -p todos


## Docker Swarm
docker swarm init --advertise-addr 10.24.38.115

docker swarm join --token SWMTKN-1-1xi7gjyzffofwpwdtz33tifdtw2d2zog4ggo9477nrvjh7zklr-89e8w5sx5rfnh7yf5e6pl319k 10.24.38.115:2377