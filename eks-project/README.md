# Lab: Deploy App on EKS with ECR, ALB Ingress & ACM

## Step 1: Create EKS Cluster
```bash
eksctl create cluster --name demo-cluster --region us-east-1 --nodes 3
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
kubectl get nodes
```

---

## Step 2: Push App Image to ECR
1. Create ECR repo:
```bash
aws ecr create-repository --repository-name eks-html-app --region us-east-1
```

2. Authenticate Docker to ECR:
```bash
aws ecr get-login-password --region us-east-1 | \
docker login --username AWS --password-stdin <account_id>.dkr.ecr.us-east-1.amazonaws.com
```

3. Build & push:
```bash
docker build -t eks-html-app:latest .
docker tag eks-html-app:latest <account_id>.dkr.ecr.us-east-1.amazonaws.com/eks-html-app:latest
docker push <account_id>.dkr.ecr.us-east-1.amazonaws.com/eks-html-app:latest
```

---

## Step 3: Deployment
```bash
cat >> deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-deploy
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
          image: <account_id>.dkr.ecr.us-east-1.amazonaws.com/eks-html-app:latest
          ports:
            - containerPort: 80
EOF
kubectl apply -f deployment.yaml
```

---

## Step 4: Service (ClusterIP)
```bash
cat >> service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: html-service
spec:
  type: ClusterIP
  selector:
    app: html-app
  ports:
    - port: 80
      targetPort: 80
EOF
kubectl apply -f service.yaml
```

---

## Step 5: Install AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set region=us-east-1
```

---

## Step 6: Request ACM Certificate
```bash
aws acm request-certificate \
  --domain-name app.example.com \
  --validation-method DNS \
  --region us-east-1
```
- Validate via Route53 DNS.

---

## Step 7: Ingress with ACM
```bash
cat >> ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: html-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/abcd-efgh
spec:
  rules:
    - host: app.example.com
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

## Step 8: Test
```bash
kubectl get ingress html-ingress
curl https://app.example.com
```

- You should see your HTML app served securely via HTTPS.

---

# End Result
- **ECR** hosts your container image.  
- **EKS** runs the app with Deployment + Service.  
- **ALB Ingress Controller** provisions ALB automatically.  
- **ACM** provides TLS termination for HTTPS.  
- **App accessible** at `https://app.example.com`.


#  Lab: Secure Web App on EKS with ALB + WAF

## Step 1: Create EKS Cluster
```bash
eksctl create cluster --name demo-cluster --region us-east-1 --nodes 3
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
kubectl get nodes
```

---

## Step 2: Sample HTML App
**Dockerfile**
```bash
cat >> Dockerfile <<'EOF'
FROM nginx:alpine
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 80
EOF
```

**index.html**
```bash
cat >> index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>EKS ALB + WAF Demo</title>
</head>
<body>
  <h1>Hello from EKS!</h1>
  <p>This app is protected by AWS WAF.</p>
</body>
</html>
EOF
```

Build & push:
```bash
docker build -t <dockerhub_user>/eks-html-app:latest .
docker push <dockerhub_user>/eks-html-app:latest
```

---

## Step 3: Deployment
```bash
cat >> deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: html-deploy
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
          image: <dockerhub_user>/eks-html-app:latest
          ports:
            - containerPort: 80
EOF
kubectl apply -f deployment.yaml
```

---

## Step 4: Service (ClusterIP)
```bash
cat >> service.yaml <<'EOF'
apiVersion: v1
kind: Service
metadata:
  name: html-service
spec:
  type: ClusterIP
  selector:
    app: html-app
  ports:
    - port: 80
      targetPort: 80
EOF
kubectl apply -f service.yaml
```

---

## Step 5: Install AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set region=us-east-1
```

---

## Step 6: Request ACM Certificate
```bash
aws acm request-certificate \
  --domain-name app.example.com \
  --validation-method DNS \
  --region us-east-1
```
- Validate via Route53.

---

## Step 7: Create WAF WebACL
```bash
aws wafv2 create-web-acl \
  --name eks-web-acl \
  --scope REGIONAL \
  --default-action Allow={} \
  --rules '[]' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=eksWebACL \
  --region us-east-1
```
- Note the WebACL ARN.

---

## Step 8: Ingress with ACM + WAF
```bash
cat >> ingress.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: html-ingress
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/abcd-efgh
    alb.ingress.kubernetes.io/waf-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/eks-web-acl/abcd1234
spec:
  rules:
    - host: app.example.com
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

## Step 9: Test
```bash
kubectl get ingress html-ingress
curl https://app.example.com
```

- You should see the HTML page served from EKS.  
- WAF filters malicious requests (SQL injection, XSS, rate limiting if rules are added).

---

# End Result
- **ALB Ingress Controller** provisions ALB.  
- **ACM** provides TLS termination.  
- **AWS WAF WebACL** protects the app.  
- **Sample HTML app** deployed on EKS, accessible via HTTPS.  
- Architecture is **simple, secure, cost‑effective** — ideal for web apps and microservices.



---

# WAF Testing Lab (ALB + WAF)

## Step 1: Confirm Setup
- You already have:
  - **ALB Ingress Controller** installed.  
  - **Ingress resource** annotated with your **ACM certificate ARN** and **WAF WebACL ARN**.  
  - A sample app (HTML or Node.js frontend) exposed via ALB.  

Check:
```bash
kubectl get ingress html-ingress
```
Note the ALB DNS name.

---

## Step 2: Add WAF Rules
Update your WebACL with some basic protections:

```bash
aws wafv2 update-web-acl \
  --name eks-web-acl \
  --scope REGIONAL \
  --id <webacl_id> \
  --default-action Allow={} \
  --rules '[
    {
      "Name": "SQLiRule",
      "Priority": 1,
      "Statement": {
        "SqliMatchStatement": {
          "FieldToMatch": { "AllQueryArguments": {} },
          "TextTransformations": [{ "Priority": 0, "Type": "NONE" }]
        }
      },
      "Action": { "Block": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "SQLiRule"
      }
    },
    {
      "Name": "RateLimitRule",
      "Priority": 2,
      "Statement": {
        "RateBasedStatement": { "Limit": 100, "AggregateKeyType": "IP" }
      },
      "Action": { "Block": {} },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimitRule"
      }
    }
  ]' \
  --region us-east-1
```

---

## Step 3: Normal Traffic Test
```bash
curl https://app.example.com
```
- Should return your HTML page.

---

## Step 4: SQL Injection Test
```bash
curl "https://app.example.com?user=' OR 1=1 --"
```
- Should be **blocked by WAF** (HTTP 403).

---

## Step 5: Rate Limit Test
```bash
for i in {1..200}; do curl -s https://app.example.com; done
```
After ~100 requests/minute from the same IP, WAF should start blocking (HTTP 403).

---

## Step 6: Monitor Logs
- Go to **CloudWatch → Metrics → WAF**.  
- You’ll see counters for blocked requests under your WebACL rules.  
- Use **Sampled Requests** in WAF console to inspect blocked traffic.

---

# End Result
- **ALB Ingress** routes traffic into EKS.  
- **ACM** provides HTTPS.  
- **AWS WAF WebACL** blocks SQL injection and rate‑limited traffic.  
- You can **verify with curl tests** and **CloudWatch metrics**.  

---

# Full Stack App on EKS with AWS WAF

## Step 1: Create EKS Cluster
```bash
eksctl create cluster --name demo-cluster --region us-east-1 --nodes 3
aws eks update-kubeconfig --region us-east-1 --name demo-cluster
kubectl get nodes
```

---

## Step 2: Build & Push Frontend Image
```bash
docker build -t <dockerhub_user>/eks-mysql-frontend:latest .
docker push <dockerhub_user>/eks-mysql-frontend:latest
```

---

## Step 3: MySQL Secrets
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

## Step 4: MySQL Headless Service
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

## Step 5: MySQL StatefulSet with EBS PVC
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

## Step 6: Frontend Secret
```bash
cat >> mysql-frontend-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: mysql-frontend-secret
type: Opaque
data:
  db-user: cm9vdA==             # "root"
  db-password: bXlzcWwtcGFzc3dvcmQ=   # "mysql-password"
  db-host: bXlzcWwtMC5teXNxbA==       # "mysql-0.mysql"
  db-name: ZWtzX2RlbW8=               # "eks_demo"
EOF
kubectl apply -f mysql-frontend-secret.yaml
```

---

## Step 7: Frontend ConfigMap
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

## Step 8: Frontend Deployment (Secrets + ConfigMap)
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
          image: <dockerhub_user>/eks-mysql-frontend:latest
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
kubectl apply -f frontend-deployment.yaml
```

---

## Step 9: Frontend Service (LoadBalancer)
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

## Step 10: Install AWS Load Balancer Controller
```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=demo-cluster \
  --set region=us-east-1
```

---

## Step 11: Request ACM Certificate
```bash
aws acm request-certificate \
  --domain-name frontend.example.com \
  --validation-method DNS \
  --region us-east-1
```

---

## Step 12: Create WAF WebACL
```bash
aws wafv2 create-web-acl \
  --name eks-web-acl \
  --scope REGIONAL \
  --default-action Allow={} \
  --rules '[]' \
  --visibility-config SampledRequestsEnabled=true,CloudWatchMetricsEnabled=true,MetricName=eksWebACL \
  --region us-east-1
```

---

## Step 13: Ingress with ACM + WAF
```bash
cat >> ingress-acm-waf.yaml <<'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress-acm-waf
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:123456789012:certificate/abcd-efgh
    alb.ingress.kubernetes.io/waf-acl-arn: arn:aws:wafv2:us-east-1:123456789012:regional/webacl/eks-web-acl/abcd1234
spec:
  rules:
    - host: frontend.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: mysql-frontend-lb
                port:
                  number: 80
EOF
kubectl apply -f ingress-acm-waf.yaml
```

---

## Step 14: Frontend HPA
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
    name: mysql-frontend
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

## Step 15: Test End‑to‑End
- Get ALB DNS:
```bash
kubectl get ingress frontend-ingress-acm-waf
```
- Test app:
```bash
curl https://frontend.example.com
```
Expected JSON:
```json
{
  "message": "Connected to MySQL StatefulSet via Secret!",
  "databases": [
    { "Database": "eks_demo" },
    ...
  ]
}
```
- Generate load:
```bash
kubectl run -it loadgen --image=busybox -- /bin/sh
while true; do wget -q -O- https://frontend.example.com; done
```
- Watch scaling:
```bash
kubectl get pods -l app=mysql-frontend -w
```

