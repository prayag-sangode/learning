# Kubernetes Ad‑hoc Imperative Commands

### Run a single Nginx Pod
```bash
kubectl run nginx --image=nginx:latest --restart=Never --port=80
```

### Expose Pod as a Service (ClusterIP)
```bash
kubectl expose pod nginx --port=80 --target-port=80 --name=nginx-service
```

### Expose Pod as a Service (NodePort)
```bash
kubectl expose pod nginx --port=80 --target-port=80 --name=nginx-nodeport --type=NodePort
```

### Create a Deployment
```bash
kubectl create deployment nginx-deploy --image=nginx:latest
```

### Scale Deployment
```bash
kubectl scale deployment nginx-deploy --replicas=3
```

### Expose Deployment as a Service
```bash
kubectl expose deployment nginx-deploy --port=80 --target-port=80 --name=nginx-deploy-service --type=NodePort
```

### Generate YAML from Imperative Command
```bash
kubectl create deployment nginx-deploy --image=nginx:latest --dry-run=client -o yaml > nginx-deploy.yaml
```

### Add Resource Limits
```bash
kubectl set resources deployment nginx-deploy --limits=cpu=500m,memory=256Mi --requests=cpu=250m,memory=128Mi
```

### Update Image
```bash
kubectl set image deployment nginx-deploy nginx=nginx:1.25.0
```

### Autoscale Deployment (HPA)
```bash
kubectl autoscale deployment nginx-deploy --cpu-percent=50 --min=1 --max=5
```

### Debugging
```bash
kubectl logs -f pod/nginx
kubectl exec -it pod/nginx -- bash
kubectl describe pod nginx
```

### Cleanup
```bash
kubectl delete pod nginx
kubectl delete deployment nginx-deploy
kubectl delete svc nginx-service nginx-nodeport nginx-deploy-service
kubectl delete hpa nginx-deploy
```

---

# Deploying a Simple HTML App

## Step 1: Dockerfile
```bash
cat >> Dockerfile <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF
```

## Step 2: index.html
```bash
cat >> index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>Kubernetes HTML App</title>
</head>
<body>
  <h1>Hello from Kubernetes!</h1>
  <p>This page is served inside a Kubernetes Pod.</p>
</body>
</html>
EOF
```

Build & push image:
```bash
docker build -t <your_dockerhub_username>/k8s-html-app:latest .
docker push <your_dockerhub_username>/k8s-html-app:latest
```

---

## Step 3: Pod Manifest
```bash
cat >> pod.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: html-pod
  labels:
    app: html-app
spec:
  containers:
    - name: html-container
      image: <your_dockerhub_username>/k8s-html-app:latest
      ports:
        - containerPort: 80
EOF
kubectl apply -f pod.yaml
kubectl get pods
```

---

## Step 4: Deployment
```bash
cat >> deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-deploy
spec:
  replicas: 3
  selector:
    matchLabels:
      app: html-app
  template:
    metadata:
      labels:
        app: html-app
    spec:
      containers:
        - name: html-container
          image: <your_dockerhub_username>/k8s-html-app:latest
          ports:
            - containerPort: 80
EOF
kubectl apply -f deployment.yaml
```

---

## Step 5: Service (NodePort)
```bash
cat >> service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: html-service
spec:
  type: NodePort
  selector:
    app: html-app
  ports:
    - port: 80
      targetPort: 80
      nodePort: 30080
EOF
kubectl apply -f service.yaml
```

Test:
```bash
curl http://<node_ip>:30080
```

---

## Step 6: ConfigMap & Secret
```bash
cat >> configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: html-config
data:
  APP_ENV: production
EOF
kubectl apply -f configmap.yaml

cat >> secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: html-secret
type: Opaque
data:
  db_password: U3VwZXJTZWNyZXQxMjMh
EOF
kubectl apply -f secret.yaml
```

---

## Step 7: Deployment with ConfigMap & Secret
```bash
cat >> deployment-config.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-deploy-config
spec:
  replicas: 2
  selector:
    matchLabels:
      app: html-app
  template:
    metadata:
      labels:
        app: html-app
    spec:
      containers:
        - name: html-container
          image: <your_dockerhub_username>/k8s-html-app:latest
          ports:
            - containerPort: 80
          env:
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: html-config
                  key: APP_ENV
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: html-secret
                  key: db_password
EOF
kubectl apply -f deployment-config.yaml
```

---

## Step 8: Persistent Volume Claim
```bash
cat >> pvc.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: html-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
kubectl apply -f pvc.yaml
```

---

## Step 9: Ingress
```bash
cat >> ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: html-ingress
spec:
  rules:
    - host: html.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: html-service
                port:
                  number: 80
EOF
kubectl apply -f ingress.yaml
```

---

## Step 10: Resource Limits
```bash
cat >> limits.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: html-limited
spec:
  containers:
    - name: html-container
      image: <your_dockerhub_username>/k8s-html-app:latest
      resources:
        requests:
          cpu: "250m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
EOF
kubectl apply -f limits.yaml
```

---

## Step 11: Horizontal Pod Autoscaler (HPA)

### Install Metrics Server
```bash
minikube addons enable metrics-server
```
or
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

### Deployment with Requests
```bash
cat >> deployment-hpa.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-deploy-hpa
spec:
  replicas: 1
  selector:
    matchLabels:
      app: html-app-hpa
  template:
    metadata:
      labels:
        app: html-app-hpa
    spec:
      containers:
        - name: html-container
          image: <your_dockerhub_username>/k8s-html-app:latest
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "256Mi"
EOF
kubectl apply -f deployment-hpa.yaml
```

### Service
```bash
cat >> service-hpa.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: html-service-hpa
spec:
  type: ClusterIP
  selector:
    app: html-app-hpa
  ports:
    - port: 80
      targetPort: 80
EOF
kubectl apply -f service-hpa.yaml
```

### HPA Manifest
```bash
cat >> hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: html-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: html-deploy-hpa
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
EOF
kubectl apply -f hpa.yaml
```

### Verify
```bash
kubectl get hpa
kubectl describe hpa html-hpa
```

### Generate Load
```bash
kubectl run -it load-generator --image=busybox -- /bin/sh
while true; do wget -q -O- http://html-service-hpa; done
```

Watch scaling:
```bash
kubectl get pods -w
```

---

## Step 12: Helm Chart
```bash
helm create html-chart
# Edit values.yaml -> image: <your_dockerhub_username>/k8s-html-app:latest
helm install html-release ./html-chart
helm list
helm uninstall html-release
```

---

## Step 13: Security (NetworkPolicy)
```bash
cat >> networkpolicy.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: html-deny-all
spec:
  podSelector:
    matchLabels:
      app: html-app
  policyTypes:
  - Ingress
  - Egress
EOF
kubectl apply -f networkpolicy.yaml
```

---

## Learning Outcomes
- Deploy a **real HTML app** into Kubernetes.  
- Use Pods, Deployments, Services, ConfigMaps, Secrets, PVCs, In
- Quickly launch Nginx with **imperative commands**.  
- Expose Pods/Deployments via **ClusterIP** and **NodePort**.  
- Scale deployments and set resource limits.  
- Update images and roll out changes.  
- Apply **Horizontal Pod Autoscaler (HPA)** imperatively.  
- Debug with logs, exec, and describe.  
- Clean up resources efficiently.  


