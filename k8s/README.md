# Kubernetes deployment (OKE)

```bash
# 1. Pull credentials for OCIR into the cluster namespace
kubectl create namespace platform --dry-run=client -o yaml | kubectl apply -f -
kubectl -n platform create secret docker-registry ocir-secret \
  --docker-server=iad.ocir.io \
  --docker-username="$OCIR_USERNAME" \
  --docker-password="$OCIR_AUTH_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

# 2. Point the kustomization at your tenancy namespace
sed -i "s/NAMESPACE/<your-object-storage-namespace>/" k8s/kustomization.yaml

# 3. Deploy
kubectl apply -k k8s

# 4. Wait for the OCI cloud controller to provision the Service LB
kubectl -n platform get svc platform-api -w
curl "http://$(kubectl -n platform get svc platform-api -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/health"
```

`Service type=LoadBalancer` is reconciled by the OKE cloud controller into an
OCI flexible load balancer in the public subnet. The Terraform-managed LB is
the VM-plane ingress; this is the Kubernetes-plane ingress.
