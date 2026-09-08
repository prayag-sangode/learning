## Docker Ad‑hoc Commands

### Check Docker version
```bash
docker --version
```

### Pull an image from Docker Hub
```bash
docker pull ubuntu:24.04
```

### Run a container interactively
```bash
docker run -it ubuntu:24.04 bash
```

### List running containers
```bash
docker ps
```

### List all containers (including stopped)
```bash
docker ps -a
```

### Stop a container
```bash
docker stop <container_id>
```

### Remove a container
```bash
docker rm <container_id>
```

### Remove an image
```bash
docker rmi ubuntu:24.04
```

### List images
```bash
docker images
```

### List volumes
```bash
docker volume ls
```

### Remove unused containers, images, networks, volumes
```bash
docker system prune -a
```

---

# Working with Docker

## Step 1: Create Files

### Dockerfile
```bash
cat >> Dockerfile <<'EOF'
# Use Ubuntu as base image
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y nginx && \
    rm -rf /var/lib/apt/lists/*

# Copy HTML app
COPY index.html /var/www/html/index.html

# Example environment variables for app config
ENV APP_ENV=production
ENV API_URL=https://api.example.com

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
```

### index.html
```bash
cat >> index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Simple HTML App</title>
</head>
<body>
  <h1>Hello from Ubuntu + Nginx!</h1>
  <p>This page is served using Nginx inside a Docker container.</p>
</body>
</html>
EOF
```

### db_secret.env
```bash
cat >> db_secret.env <<'EOF'
db_password=SuperSecret123!
EOF
```

---

## Step 2: Build Image
```bash
docker build -t html-app .
```

---

## Step 3: Run Containers
```bash
docker run -d -p 8081:80 html-app
docker run -d -p 8082:80 -e APP_ENV=development -e API_URL=https://dev-api.example.com html-app
docker run -d -p 8083:80 -v $(pwd)/db_secret.env:/run/secrets/db_secret.env:ro html-app
```

---

## Step 4: Bind Mounts (Live Editing)
```bash
docker run -d -p 8084:80 -v $(pwd)/index.html:/var/www/html/index.html:ro html-app
```

---

## Step 5: Named Docker Volumes
```bash
docker volume create html_data
docker volume ls
docker run -d -p 8085:80 -v html_data:/var/www/html html-app
docker volume inspect html_data
docker cp index.html <container_id>:/var/www/html/index.html
```

---

## Step 6: Inspect & Debug
```bash
docker ps
docker logs <container_id>
docker exec -it <container_id> bash
docker inspect <container_id>
docker stats
docker events
```

---

## Step 7: Stop & Remove
```bash
docker stop <container_id>
docker rm <container_id>
docker rmi html-app
```

---

## Step 8: Clean Up Volumes & System
```bash
docker volume rm html_data
docker volume prune
docker system prune -a
docker system df
docker info
```

---

## Step 9: Ephemeral vs Persistent Demo
```bash
docker run -it --name ephemeral-test ubuntu:24.04 bash
echo "Hello Ephemeral World" > /tmp/test.txt
exit
docker start -ai ephemeral-test
cat /tmp/test.txt   # File exists
docker rm -f ephemeral-test
docker run -it ubuntu:24.04 bash
cat /tmp/test.txt   # File gone
```

With volume:
```bash
docker volume create persist-demo
docker run -it -v persist-demo:/data ubuntu:24.04 bash
echo "Persistent data survives!" > /data/keep.txt
exit
docker rm -f <container_id>
docker run -it -v persist-demo:/data ubuntu:24.04 bash
cat /data/keep.txt   # File survives
```

---

## Step 10: Build Image again
```bash
docker build -t html-app .
```

---

## Step 11: Run Locally & Test
```bash
docker run -d -p 8081:80 html-app
curl http://localhost:8081
```

---

## Step 12: Docker Hub Setup
```bash
docker login
```

---

## Step 13: Tag & Push Image
```bash
docker tag html-app <your_dockerhub_username>/html-app:latest
docker push <your_dockerhub_username>/html-app:latest
```

---

## Step 14: Pull & Run from Docker Hub
```bash
docker pull <your_dockerhub_username>/html-app:latest
docker run -d -p 8082:80 <your_dockerhub_username>/html-app:latest
curl http://localhost:8082
```

---

## Step 15: Inspect, Stop, Remove
```bash
docker ps
docker logs <container_id>
docker exec -it <container_id> bash
docker stop <container_id>
docker rm <container_id>
docker rmi <your_dockerhub_username>/html-app:latest
```

---

## Step 16: Volumes & Cleanup
```bash
docker volume create html_data
docker volume ls
docker volume inspect html_data
docker volume rm html_data
docker volume prune
docker system prune -a
```

---

## Step 17: Working with Multiple Containers (Hello Demo)
```bash
docker network create hello-net
docker run -d --name hello-backend --network hello-net -p 9000:5678 hashicorp/http-echo:0.2.3 -text="Hello from Backend"
docker run -d --name hello-frontend --network hello-net -p 9001:5678 hashicorp/http-echo:0.2.3 -text="Hello from Frontend"
curl http://localhost:9000
curl http://localhost:9001
docker exec -it hello-frontend curl http://hello-backend:5678
```

---

## Step 18: Inspect Networks
```bash
docker network ls
docker network inspect hello-net
```

---

## Step 19: Stop & Remove Multiple Containers
```bash
docker stop hello-frontend hello-backend
docker rm hello-frontend hello-backend
docker network rm hello-net
```

---

## Step 20: Docker Compose Basics
Create `docker-compose.yml`:
```yaml
version: "3.9"
services:
  frontend:
    image: hashicorp/http-echo:0.2.3
    command: ["-text=Hello from Frontend"]
    ports:
      - "9001:5678"
  backend:
    image: hashicorp/http-echo:0.2.3
    command: ["-text=Hello from Backend"]
    ports:
      - "9000:5678"
```

Run:
```bash
docker compose up -d
curl http://localhost:9000
curl http://localhost:9001
docker compose down
```

---

## Step 21: Resource Limits
```bash
docker run -d --name limited-app --memory="256m" --cpus="0.5" html-app
docker stats limited-app
```

---

## Step 22: Dockerfile Optimization
Example multi‑stage build:
```dockerfile
FROM ubuntu:24.04 AS builder
RUN echo "Building app..."
FROM nginx:alpine
COPY --from=builder /usr/share/nginx/html /usr/share/nginx/html
```

---

## Learning Outcomes
- Ad‑hoc Docker commands.  
- Build/run images with ENV, secrets, bind mounts, volumes.  
- Debug with logs, exec, inspect, stats, events.  
- Stop, remove, prune, system management.  
- Ephemeral vs persistent demo.  
- Docker Hub push/pull workflow.  
- Multi‑container networking.  
- Docker Compose orchestration.  
- Resource limits.  
- Dockerfile optimization.  

---

This README.md is now a **complete Docker fundamentals lab guide** — perfect for Day‑1 learners and a strong foundation for moving into Kubernetes.
