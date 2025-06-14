# 🐸 Installing JFrog Artifactory on K3s with Helm

This guide describes how to install **JFrog Artifactory on a **K3s** cluster using **Helm**, and access it from your Mac using `kubectl port-forward` in the background.

---

## ✅ Prerequisites

- A running K3s cluster (single-node or multi-node)
- `kubectl` configured and working
- `helm` installed (v3+)
- Internet access from the K3s node or configured proxy (e.g., via ClashX)

---

## 📥 Step 1: Add the JFrog Helm Repository

```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update
```

---

## 📂 Step 2: Create Namespace

```bash
kubectl create namespace artifactory
```

---

## 🔐 Step 3: Generate Required Keys

Artifactory requires a `masterKey` and a `joinKey` (must be 32-character strings):

```bash
export MASTER_KEY=$(openssl rand -hex 16)
export JOIN_KEY=$(openssl rand -hex 16)
```

---

## 🚀 Step 4: Install Artifactory via Helm

```bash
helm upgrade --install artifactory --set artifactory.masterKey=${MASTER_KEY} --set artifactory.joinKey=${JOIN_KEY} --namespace artifactory --create-namespace jfrog/artifactory

```

> You can also use a `values.yaml` file for advanced configuration (persistence, ingress, database, etc.).

---

## ⏱️ Step 5: Wait for Pods to Become Ready

```bash
kubectl get pods -n artifactory -w
```

Wait until all pods are in `Running` state.

---

## 🌐 Step 6: Expose Artifactory with Port-Forward (in Background)

```bash
nohup kubectl port-forward svc/artifactory-artifactory-nginx 80:80 -n artifactory > port-forward.log 2>&1 &
```

This will expose Artifactory to `http://localhost/artifactory`.

You can now open your browser and visit:

```
http://localhost/artifactory
```

---

## 🛑 Step 7: Stop Port-Forwarding

```bash
pkill -f "kubectl port-forward svc/artifactory-artifactory-nginx"
```

---

## 🧪 Helpful Commands

Check services:

```bash
kubectl get svc -n artifactory
```

Check logs of port-forwarding:

```bash
tail -f port-forward.log
```

---

## 📎 References

- [JFrog Artifactory Helm Chart](https://github.com/jfrog/charts/tree/master/stable/artifactory)
- [K3s Documentation](https://docs.k3s.io/)
- [Helm Docs](https://helm.sh/docs/)

# 🛠️ Installing JFrog Xray on K3s with Helm

This guide walks you through deploying **JFrog Xray** on a K3s Kubernetes cluster using Helm.

---

## 📦 Prerequisites

- ✅ K3s cluster up and running
- ✅ Helm installed (`helm version`)
- ✅ `kubectl` configured to access the K3s cluster
- ✅ Artifactory already installed in namespace `artifactory`

---

## 🔐 1. Prepare Secrets

### 👉 Create the PostgreSQL password Secret

```bash
kubectl create namespace xray

kubectl create secret generic xray-postgresql \
  -n xray \
  --from-literal=password=MyActualPgPassword123 \
  --from-literal=postgres-password=MyActualPgPassword123
```

### 👉 Create the joinKey Secret

```bash
kubectl create secret generic joinkey-secret \
  --from-literal=join-key=YOUR_JOIN_KEY \
  -n xray
```

### 👉 (Optional) MasterKey Secret if required:

```bash
kubectl create secret generic masterkey-secret \
  --from-literal=master-key=YOUR_MASTER_KEY \
  -n xray
```

---

## ⚙️ 2. Prepare `xray-values.yaml`

```yaml
xray:
  joinKeySecretName: joinkey-secret
  masterKeySecretName: masterkey-secret

  database:
    host: xray-postgresql
    user: xray
    existingSecret: xray-postgresql
    existingSecretKey: password

  jfrogUrl: http://artifactory-artifactory-nginx.artifactory.svc.cluster.local

postgresql:
  enabled: true
  auth:
    existingSecret: xray-postgresql
    username: xray
    database: xraydb
```

Save as `xray-values.yaml`.

---

## 🚀 3. Install Xray via Helm

```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update

helm upgrade --install xray jfrog/xray \
  -n xray \
  -f xray-values.yaml \
  --set unifiedUpgradeAllowed=true
```

---

## ✅ 4. Verify Installation

```bash
kubectl get pods -n xray
kubectl get svc -n xray
```

Ensure all Xray pods are `Running`.


---

## 🧪 6. Test Database Access (Optional)

```bash
kubectl run psql-test -n xray --rm -it --image=bitnami/postgresql -- bash

# Then inside container:
export PGPASSWORD=MyActualPgPassword123
psql -U xray -h xray-postgresql -d xraydb
```

---

## 🧹 7. Uninstall (if needed)

```bash
helm uninstall xray -n xray
kubectl delete pvc -n xray -l app.kubernetes.io/name=postgresql
```

---

## 📌 Notes

- Ensure PostgreSQL PVC is cleared if reinstalling with new credentials.
- Password mismatch is the most common cause of startup failures.
- Always specify `unifiedUpgradeAllowed=true` when upgrading from Xray 3.x.


# 📦 Exporting Docker Images for Offline Installation of JFrog Artifactory and Xray (K3s)

This guide describes how to **export all Docker images** required for **offline installation** of **JFrog Artifactory** and **Xray** on a K3s cluster.

---

## ✅ 1. Prerequisites

- Internet-connected Linux machine with:
  - Docker or Podman installed
  - Helm installed
  - `helm repo add jfrog https://charts.jfrog.io`
- Target air-gapped environment:
  - K3s cluster installed
  - Optional: Local Docker registry in the offline environment

---

## 📥 2. Add Helm Repo and Update

```bash
helm repo add jfrog https://charts.jfrog.io
helm repo update
```

---

## 🔍 3. Generate Required Image Lists

### ✳️ Artifactory

```bash
helm template artifactory jfrog/artifactory --namespace artifactory   --set artifactory.masterKey=EXAMPLE_MASTER_KEY   --set artifactory.joinKey=EXAMPLE_JOIN_KEY   | grep image: | awk '{print $2}' | sort | uniq > artifactory-images.txt
```

### ✳️ Xray

Ensure you have a `xray-values.yaml` that includes:

```yaml
xray:
  jfrogUrl: http://artifactory-artifactory-nginx.artifactory.svc.cluster.local

rabbitmq:
  auth:
    password: SecureRabbit123
```

Then run:

```bash
helm template xray jfrog/xray --namespace xray -f xray-values.yaml   | grep image: | awk '{print $2}' | sort | uniq > xray-images.txt
```

---

## 💾 4. Download and Save Docker Images

```bash
cat artifactory-images.txt xray-images.txt | sort | uniq | while read image; do
  docker pull "$image"
done

mkdir -p jfrog-images
cat artifactory-images.txt xray-images.txt | sort | uniq | while read image; do
  sanitized=$(echo "$image" | tr '/:' '_')
  docker save "$image" -o jfrog-images/${sanitized}.tar
done
```

---

## 🚚 5. Transfer Images to Offline Machine

You can use `scp`, USB, or portable SSD:

```bash
scp -r jfrog-images/ user@offline-node:/path/to/import
```

---

## 📦 6. Load Images on Air-Gapped K3s Node

```bash
cd /path/to/import/jfrog-images

for tar in *.tar; do
  docker load -i "$tar"
done
```

> If using containerd in K3s, use: `ctr -n=k8s.io images import <image.tar>`

---

## ✅ 7. Proceed with Helm Install Offline

```bash
helm upgrade --install artifactory jfrog/artifactory -n artifactory -f artifactory-values.yaml
helm upgrade --install xray jfrog/xray -n xray -f xray-values.yaml
```

---

## 📌 Notes

- You must provide valid `masterKey`, `joinKey`, and RabbitMQ credentials.
- Always test image loading before Helm deployment.
- Use `--dry-run` on Helm to confirm chart rendering before installation.
