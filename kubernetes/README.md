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

Got it — let’s finalize the **EKS‑specific crash course README.md** with **all YAML manifests included via `cat >> EOF`** so it’s copy‑paste ready. This version assumes you’ve already created an EKS cluster with `eksctl` and configured `kubectl`.

---

# ☸️ Kubernetes Crash Course on AWS EKS (HTML App)

## ⚡ Pre‑requisites
```bash
eksctl create cluster --name demo-cluster --region us-east-1 --nodes 3
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
kubectl get nodes
```

---

## ⚡ Imperative Commands (Nginx on EKS)
```bash
kubectl run nginx --image=nginx:latest --restart=Never --port=80
kubectl expose pod nginx --port=80 --target-port=80 --name=nginx-service
kubectl expose pod nginx --port=80 --target-port=80 --name=nginx-nodeport --type=NodePort
kubectl create deployment nginx-deploy --image=nginx:latest
kubectl scale deployment nginx-deploy --replicas=3
kubectl expose deployment nginx-deploy --port=80 --target-port=80 --name=nginx-deploy-service --type=NodePort
kubectl autoscale deployment nginx-deploy --cpu-percent=50 --min=1 --max=5
```

Test:
```bash
kubectl get svc nginx-nodeport
curl http://<worker_node_public_ip>:<nodePort>
```

---

# 🛠 Deploying HTML App on EKS

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
  <h1>Hello from Kubernetes on EKS!</h1>
  <p>This page is served inside an EKS Pod.</p>
</body>
</html>
EOF
```

Build & push:
```bash
docker build -t <your_dockerhub_username>/k8s-html-app:latest .
docker push <your_dockerhub_username>/k8s-html-app:latest
```

---

## Step 3: Pod
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

Test:
```bash
kubectl port-forward pod/html-pod 8080:80
curl http://localhost:8080
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

Test:
```bash
kubectl port-forward deployment/html-deploy 8081:80
curl http://localhost:8081
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
curl http://<worker_node_public_ip>:30080
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

Test:
```bash
kubectl port-forward deployment/html-deploy-config 8082:80
curl http://localhost:8082
```

---

## Step 8: PVC (EBS backed on EKS)
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
storageClassName: gp2
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

Test:
```bash
kubectl get ingress
curl http://<ALB_or_ELB_hostname>
```

---

# Nginx Ingress Controller (Helm on EKS)
```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace
kubectl get svc -n ingress-nginx
```

---

# Cert‑Manager (Helm on EKS)
```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true
kubectl get pods -n cert-manager
```

---

## Step 10: ClusterIssuer
```bash
cat >> issuer.yaml <<'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
kubectl apply -f issuer.yaml
```

---

## Step 11: TLS Ingress
```bash
cat >> ingress-tls.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: html-ingress-tls
spec:
  tls:
  - hosts:
    - html.local
    secretName: html-tls
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
kubectl apply -f ingress-tls.yaml
```

Test:
```bash
curl -k https://html.local
```
---

## Step 12: Horizontal Pod Autoscaler (HPA on EKS)

### Metrics Server (required for HPA)
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
```

Inside the BusyBox shell:
```bash
while true; do wget -q -O- http://html-service-hpa; done
```

Watch scaling:
```bash
kubectl get pods -w
```

Test service locally:
```bash
kubectl port-forward service/html-service-hpa 8085:80
curl http://localhost:8085
```

---

## Step 13: Helm Chart
```bash
helm create html-chart
# Edit values.yaml -> image: <your_dockerhub_username>/k8s-html-app:latest
helm install html-release ./html-chart
helm list
helm uninstall html-release
```

---

## Step 14: Security (NetworkPolicy)
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

## Step 15: AWS LoadBalancer Service (ELB/ALB)

```bash
cat >> service-lb.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: html-service-lb
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: "nlb"   # or "alb" for Application Load Balancer
spec:
  type: LoadBalancer
  selector:
    app: html-app
  ports:
    - port: 80
      targetPort: 80
EOF
kubectl apply -f service-lb.yaml
```

---

### Verify LoadBalancer
```bash
kubectl get svc html-service-lb
```

You’ll see an **EXTERNAL-IP** field populated with the AWS ELB/ALB hostname.

---

### Test Public Access
```bash
curl http://<external_hostname_or_ip>
```

---


## Step 17: AWS EBS CSI StorageClass + PVC

### Install the AWS EBS CSI Driver (if not already installed)
```bash
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster demo-cluster --approve

kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/ecr/?ref=release-1.30"
```

---

### StorageClass (gp2 or gp3)
```bash
cat >> storageclass.yaml <<'EOF'
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: ebs-sc
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3   # gp2 or gp3
  fsType: ext4
EOF
kubectl apply -f storageclass.yaml
```

---

### PersistentVolumeClaim
```bash
cat >> pvc-ebs.yaml <<'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: html-pvc-ebs
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
  storageClassName: ebs-sc
EOF
kubectl apply -f pvc-ebs.yaml
```

---

### Pod using EBS PVC
```bash
cat >> pod-ebs.yaml <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: html-pod-ebs
spec:
  containers:
    - name: html-container
      image: <your_dockerhub_username>/k8s-html-app:latest
      ports:
        - containerPort: 80
      volumeMounts:
        - name: html-storage
          mountPath: /usr/share/nginx/html
  volumes:
    - name: html-storage
      persistentVolumeClaim:
        claimName: html-pvc-ebs
EOF
kubectl apply -f pod-ebs.yaml
```

---

### Verify Storage
```bash
kubectl get pvc html-pvc-ebs
kubectl describe pvc html-pvc-ebs
kubectl get pv
```

---

### Test Pod with EBS Volume
```bash
kubectl port-forward pod/html-pod-ebs 8086:80
curl http://localhost:8086
```

---

## Step 18: StatefulSet (MySQL with EBS PVC)

### Headless Service (for stable DNS)
```bash
cat >> mysql-headless-svc.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  ports:
    - port: 3306
      name: mysql
  clusterIP: None
  selector:
    app: mysql
EOF
kubectl apply -f mysql-headless-svc.yaml
```

---

### StatefulSet with EBS PVC
```bash
cat >> mysql-statefulset.yaml <<'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql"
  replicas: 2
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:8.0
          ports:
            - containerPort: 3306
              name: mysql
          env:
            - name: MYSQL_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-secret
                  key: root-password
          volumeMounts:
            - name: mysql-persistent-storage
              mountPath: /var/lib/mysql
  volumeClaimTemplates:
    - metadata:
        name: mysql-persistent-storage
      spec:
        accessModes: [ "ReadWriteOnce" ]
        storageClassName: ebs-sc
        resources:
          requests:
            storage: 5Gi
EOF
kubectl apply -f mysql-statefulset.yaml
```

---

### Secret for MySQL Root Password
```bash
cat >> mysql-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysql-secret
type: Opaque
data:
  root-password: bXlzcWwtcGFzc3dvcmQ=   # base64 for "mysql-password"
EOF
kubectl apply -f mysql-secret.yaml
```

---

### Verify StatefulSet
```bash
kubectl get statefulset mysql
kubectl get pods -l app=mysql
kubectl get pvc
```

You’ll see pods named `mysql-0`, `mysql-1` each with its own PVC (`mysql-persistent-storage-mysql-0`, `mysql-persistent-storage-mysql-1`).

---

### Test MySQL Pod
```bash
kubectl exec -it mysql-0 -- mysql -uroot -p
# Enter password: mysql-password
```

Inside MySQL shell:
```sql
CREATE DATABASE eks_demo;
SHOW DATABASES;
```

---

## Step 19: Node.js Frontend Connecting to MySQL StatefulSet

### 1. Dockerfile
```bash
cat >> Dockerfile <<'EOF'
FROM node:18-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "app.js"]
EOF
```

---

### 2. package.json
```bash
cat >> package.json <<'EOF'
{
  "name": "eks-mysql-frontend",
  "version": "1.0.0",
  "main": "app.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0"
  }
}
EOF
```

---

### 3. app.js
```bash
cat >> app.js <<'EOF'
const express = require('express');
const mysql = require('mysql2/promise');
const app = express();

const dbConfig = {
  host: 'mysql-0.mysql',   // Headless Service DNS
  user: 'root',
  password: 'mysql-password',
  database: 'eks_demo'
};

app.get('/', async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.query('SHOW DATABASES;');
    await conn.end();
    res.json({ message: "Connected to MySQL StatefulSet!", databases: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(3000, () => {
  console.log('Frontend app running on port 3000');
});
EOF
```

---

### 4. Build & Push Image
```bash
docker build -t <your_dockerhub_username>/eks-mysql-frontend:latest .
docker push <your_dockerhub_username>/eks-mysql-frontend:latest
```

---

### 5. Deployment
```bash
cat >> frontend-deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mysql-frontend
  template:
    metadata:
      labels:
        app: mysql-frontend
    spec:
      containers:
        - name: frontend
          image: <your_dockerhub_username>/eks-mysql-frontend:latest
          ports:
            - containerPort: 3000
EOF
kubectl apply -f frontend-deployment.yaml
```

---

### 6. Service (LoadBalancer)
```bash
cat >> frontend-service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mysql-frontend-lb
spec:
  type: LoadBalancer
  selector:
    app: mysql-frontend
  ports:
    - port: 80
      targetPort: 3000
EOF
kubectl apply -f frontend-service.yaml
```

---

### 7. Verify & Test
```bash
kubectl get svc mysql-frontend-lb
```

You’ll see an **EXTERNAL-IP** (AWS ELB hostname). Test:
```bash
curl http://<external_hostname>
```

Expected output:
```json
{
  "message": "Connected to MySQL StatefulSet!",
  "databases": [
    { "Database": "eks_demo" },
    { "Database": "information_schema" },
    ...
  ]
}
```

---

## Step 20: Kubernetes Secret for DB Credentials

```bash
cat >> mysql-frontend-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysql-frontend-secret
type: Opaque
data:
  db-user: cm9vdA==             # base64 for "root"
  db-password: bXlzcWwtcGFzc3dvcmQ=   # base64 for "mysql-password"
  db-host: bXlzcWwtMC5teXNxbA==       # base64 for "mysql-0.mysql"
  db-name: ZWtzX2RlbW8=               # base64 for "eks_demo"
EOF
kubectl apply -f mysql-frontend-secret.yaml
```

---

## Step 21: Update Node.js Deployment to Use Secret

```bash
cat >> frontend-deployment-secret.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-frontend-secret
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mysql-frontend-secret
  template:
    metadata:
      labels:
        app: mysql-frontend-secret
    spec:
      containers:
        - name: frontend
          image: <your_dockerhub_username>/eks-mysql-frontend:latest
          ports:
            - containerPort: 3000
          env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-user
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-password
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-host
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-name
EOF
kubectl apply -f frontend-deployment-secret.yaml
```

---

## Step 22: Update Node.js app.js to Read Env Vars

```bash
cat >> app.js <<'EOF'
const express = require('express');
const mysql = require('mysql2/promise');
const app = express();

const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME
};

app.get('/', async (req, res) => {
  try {
    const conn = await mysql.createConnection(dbConfig);
    const [rows] = await conn.query('SHOW DATABASES;');
    await conn.end();
    res.json({ message: "Connected to MySQL StatefulSet via Secret!", databases: rows });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(3000, () => {
  console.log('Frontend app running on port 3000');
});
EOF
```

Rebuild & push:
```bash
docker build -t <your_dockerhub_username>/eks-mysql-frontend:latest .
docker push <your_dockerhub_username>/eks-mysql-frontend:latest
```

---

## Step 23: Service (LoadBalancer)
```bash
cat >> frontend-service-secret.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mysql-frontend-secret-lb
spec:
  type: LoadBalancer
  selector:
    app: mysql-frontend-secret
  ports:
    - port: 80
      targetPort: 3000
EOF
kubectl apply -f frontend-service-secret.yaml
```

---

## Step 24: Verify & Test
```bash
kubectl get svc mysql-frontend-secret-lb
```

You’ll see an **EXTERNAL-IP** (AWS ELB hostname). Test:
```bash
curl http://<external_hostname>
```

Expected output:
```json
{
  "message": "Connected to MySQL StatefulSet via Secret!",
  "databases": [
    { "Database": "eks_demo" },
    { "Database": "information_schema" },
    ...
  ]
}
```

---

## Step 25: ConfigMap for Frontend Settings
```bash
cat >> frontend-configmap.yaml <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-frontend-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
EOF
kubectl apply -f frontend-configmap.yaml
```

---

## Step 26: Deployment with ConfigMap + Secret
```bash
cat >> frontend-deployment-config-secret.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-frontend-config-secret
spec:
  replicas: 2
  selector:
    matchLabels:
      app: mysql-frontend-config-secret
  template:
    metadata:
      labels:
        app: mysql-frontend-config-secret
    spec:
      containers:
        - name: frontend
          image: <your_dockerhub_username>/eks-mysql-frontend:latest
          ports:
            - containerPort: 3000
          env:
            - name: DB_USER
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-user
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-password
            - name: DB_HOST
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-host
            - name: DB_NAME
              valueFrom:
                secretKeyRef:
                  name: mysql-frontend-secret
                  key: db-name
            - name: APP_ENV
              valueFrom:
                configMapKeyRef:
                  name: mysql-frontend-config
                  key: APP_ENV
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: mysql-frontend-config
                  key: LOG_LEVEL
EOF
kubectl apply -f frontend-deployment-config-secret.yaml
```

---

## Step 27: Service (LoadBalancer)
```bash
cat >> frontend-service-config-secret.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mysql-frontend-config-secret-lb
spec:
  type: LoadBalancer
  selector:
    app: mysql-frontend-config-secret
  ports:
    - port: 80
      targetPort: 3000
EOF
kubectl apply -f frontend-service-config-secret.yaml
```

---

## Step 28: Verify & Test
```bash
kubectl get svc mysql-frontend-config-secret-lb
```

You’ll see an **EXTERNAL-IP** (AWS ELB hostname). Test:
```bash
curl http://<external_hostname>
```

Expected output:
```json
{
  "message": "Connected to MySQL StatefulSet via Secret!",
  "databases": [
    { "Database": "eks_demo" },
    ...
  ]
}
```

---


## Step 29: Frontend HPA

### Deployment (already created in Step 26 with ConfigMap + Secret)  
We’ll reuse `mysql-frontend-config-secret` Deployment.

---

### HPA Manifest
```bash
cat >> frontend-hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: mysql-frontend-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: mysql-frontend-config-secret
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 60
EOF
kubectl apply -f frontend-hpa.yaml
```

---

### Verify HPA
```bash
kubectl get hpa mysql-frontend-hpa
kubectl describe hpa mysql-frontend-hpa
```

---

### Generate Load
```bash
kubectl run -it frontend-loadgen --image=busybox -- /bin/sh
```

Inside BusyBox shell:
```bash
while true; do wget -q -O- http://mysql-frontend-config-secret-lb; done
```

---

### Watch Scaling
```bash
kubectl get pods -l app=mysql-frontend-config-secret -w
```

---

### Test Service
```bash
kubectl get svc mysql-frontend-config-secret-lb
curl http://<external_hostname>
```

---

## Step 30: AWS WAF Integration with EKS Ingress/ALB

### 1. Install AWS Load Balancer Controller (ALB Ingress Controller)
This controller provisions ALBs for Kubernetes Ingress resources.
```bash
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster demo-cluster --approve

helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set serviceAccount.create=false \
  --set region=us-east-1
```

---

### 2. Create WAF WebACL in AWS
Use AWS Console or CLI:
```bash
aws wafv2 create-web-acl \
  --name eks-web-acl \
  --scope REGIONAL \
  --default-action Allow={} \
  --description "WAF for EKS ALB" \
  --rules '[]' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=eksWebACL \
  --region us-east-1
```

This returns a **WebACL ARN**.

---

### 3. Annotate Ingress with WAF WebACL ARN
```bash
cat >> ingress-waf.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: html-ingress-waf
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/waf-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/eks-web-acl/abcd1234-efgh5678
spec:
  rules:
    - host: html.example.com
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
kubectl apply -f ingress-waf.yaml
```

---

### 4. Verify ALB + WAF
```bash
kubectl get ingress html-ingress-waf
```
Check AWS Console → **EC2 → Load Balancers**. The ALB created will have WAF attached.

---

### 5. Test
```bash
curl http://html.example.com
```
Requests will now be filtered by WAF rules (e.g., SQL injection, XSS protection).

*** Add a **sample WAF rule set (e.g., block SQL injection, limit requests per IP)** so learners can see practical protection in action?

