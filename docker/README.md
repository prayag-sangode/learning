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

### Run with defaults
```bash
docker run -d -p 8081:80 html-app
```

### Run with ENV overrides
```bash
docker run -d -p 8082:80 \
  -e APP_ENV=development \
  -e API_URL=https://dev-api.example.com \
  html-app
```

### Run with secret file mounted
```bash
docker run -d -p 8083:80 \
  -v $(pwd)/db_secret.env:/run/secrets/db_secret.env:ro \
  html-app
```

---

## Step 4: Bind Mounts (Live Editing)
```bash
docker run -d -p 8084:80 \
  -v $(pwd)/index.html:/var/www/html/index.html:ro \
  html-app
```
- Edit `index.html` locally → refresh browser → changes appear instantly.  
- Demonstrates **bind mounts**.

---

## Step 5: Named Docker Volumes

### Create a named volume
```bash
docker volume create html_data
```

### List volumes
```bash
docker volume ls
```

### Run container with named volume
```bash
docker run -d -p 8085:80 \
  -v html_data:/var/www/html \
  html-app
```

### Inspect volume
```bash
docker volume inspect html_data
```

### Copy files into the volume
```bash
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
```

---

## Step 10: Build Image again
```bash
docker build -t html-app .
```

---

## Step 11: Run Locally
```bash
docker run -d -p 8081:80 html-app
```

### Test with curl
```bash
curl http://localhost:8081
```

---

## Step 12: Docker Hub Setup
1. Go to [Docker Hub](https://hub.docker.com) and **create an account**.  
2. Log in from your VM:
   ```bash
   docker login
   ```
   Enter your Docker Hub username and password.

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
```

### Test with curl
```bash
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

## Learning Outcomes
- Practice **ad‑hoc commands** before building files.  
- Build and run Docker images.  
- Use ENV overrides and secrets.  
- Work with bind mounts and named volumes.  
- Debug with logs, exec, inspect, stats.  
- Stop, remove, prune containers/images/volumes.  
- Push/pull images to Docker Hub and test with curl.  

