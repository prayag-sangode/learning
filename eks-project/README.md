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

