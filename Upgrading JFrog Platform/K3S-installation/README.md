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