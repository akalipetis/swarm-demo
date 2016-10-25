The following script will use the Azure Docker Machine driver to create the
needed machines. You can run it for as many machines as you'd like:

```bash
export AZURE_SUBSCRIPTION_ID=<your-azure-subscription-id-here>
for i in `seq 0 2`; do ./scripts/create-machine.sh swarm-$i; done
```

Point to the Swarm master and initilize the cluster

```bash
eval $(docker-machine env swarm-0)
docker swarm init
```

Expose the token as an environment variable

```bash
SWARM_TOKEN=$(docker swarm join-token worker -q)
```

Expose the private IP of master in the SWARM_MASTER_IP environment variable

```bash
export SWARM_MASTER_IP=$(docker-machine ssh swarm-0 hostname -I | awk '{print $1}')
```

Join the workers in the Swarm

```bash
for machine in swarm-1 swarm-2; do
    docker-machine ssh $machine sudo docker swarm join --token $SWARM_TOKEN $SWARM_MASTER_IP:2377;
done
```

Create a network and a simple service

```bash
docker network create --driver=overlay swarm-net
docker service create --name=flask-hostname --network=swarm-net --publish=30303:5000 akalipetis/flask-hostname
```

Test that the service is working

```bash
docker-machine ssh swarm-0 "bash -c 'while true; do curl localhost:30303 2>/dev/null; echo; sleep 1; done'"

# Scale the service
docker service scale flask-hostname=5

# Notice the change in hostnames

# Now scale back
docker service scale flask-hostname=1

# Notice that it slowly goes back to one hostname
```

Add a load balancer - for this, we'll use Ceryx, a dynamic load balancer based on NGINX.

First, we'll create a bundle for Ceryx.

```bash
# Pull the images
docker-compose -f ceryx.yaml pull

# Create the bundle
docker-compose -f ceryx.yaml bundle -o swarm.dab

# Deploy the bundle
docker deploy swarm

# Get the exposed port of the proxy
export PROXY_PORT=$(docker service inspect -f '{{ (index .Endpoint.Ports 0).PublishedPort }}' swarm_proxy)

# Test the proxy - make sure it returns Something
docker-machine ssh swarm-0 "bash -c 'while true; do curl localhost:$PROXY_PORT 2>/dev/null; echo; sleep 1; done'"

# Get the exposed port of the API
export API_PORT=$(docker service inspect -f '{{ (index .Endpoint.Ports 0).PublishedPort }}' swarm_api)

# Now, add a new wildcard route to the proxy
docker-machine ssh swarm-0 curl -XPOST localhost:$API_PORT/api/routes -F source=\\\$wildcard -F target=flask-hostname:5000

# Check the proxy, notice that nothing changed since the proxy and the flask-hostname are not in the same network
docker-machine ssh swarm-0 "bash -c 'while true; do curl localhost:$PROXY_PORT 2>/dev/null; echo; sleep 1; done'"
```

Let's add the flask-hostname service in the .dab file. Edit the ceryx.yaml file adding this service:

```yaml
  flask-hostname:
    image: akalipetis/flask-hostname
    networks:
      swarm-net:
```

```bash
# Update the .dab file
docker-compose -f ceryx.yaml bundle -o swarm.dab

# Redeploy the .dab file
docker deploy swarm

# Check again
docker-machine ssh swarm-0 curl -XPOST localhost:$API_PORT/api/routes -F source=\\\$wildcard -F target=flask-hostname:5000
```