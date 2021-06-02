AKS_RG_NAME="replace-me"
AKS_CLUSTER_NAME="replace-me"
GIT_USERNAME="replace-me"
GIT_SECRET="replace-me"
GIT_REPO="replace-me"
ARGO_SECRET=`kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

kubectx:
	@echo ""
	@echo "Getting Kubernetes context..."
	@echo ""
	az aks get-credentials --resource-group ${AKS_RG_NAME} --name ${AKS_CLUSTER_NAME} --overwrite

argo-install:
	@echo ""
	@echo "Installing ArgoCD..."
	@echo ""
	kubectl create namespace argocd
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	kubectl create namespace argo-rollouts
	kubectl apply -n argo-rollouts -f https://raw.githubusercontent.com/datawire/argo-rollouts/ambassador/release/manifests/install.yaml

kyverno-setup:
	@echo ""
	@echo "Setup Kyverno..."
	@echo ""
	@echo "Setup a connection to the argocd-server with the command:"
	@echo ""
	@echo "kubectl port-forward svc/argocd-server -n argocd 8080:443"
	@echo ""
	read -p "Press any key when you have established a connection..."
	argocd login localhost:8080 --username admin --password ${ARGO_SECRET} --insecure
	argocd repo add ${GIT_REPO} --type git --username ${GIT_USERNAME} --password ${GIT_SECRET}
	argocd proj create kyverno --dest https://kubernetes.default.svc,kyverno --src ${GIT_REPO} --allow-cluster-resource */* --description "kyverno"
	argocd app create kyverno --repo ${GIT_REPO} --path kyverno --dest-namespace kyverno --dest-server https://kubernetes.default.svc --auto-prune --project kyverno --self-heal --sync-policy auto 

kyverno-reporting:
	@echo ""
	@echo "Installing Kyverno reporting UI..."
	@echo ""
	helm repo add policy-reporter https://fjogeleit.github.io/policy-reporter
	helm repo update
	helm install policy-reporter policy-reporter/policy-reporter --set kyvernoPlugin.enabled=true --set ui.enabled=true --set ui.plugins.kyverno=true -n policy-reporter --create-namespace
	kubectl port-forward service/policy-reporter-ui 8082:8080 -n policy-reporter

kyverno-policies:
	@echo ""
	@echo "Installing Pod Security policies..."
	@echo ""
	kustomize build https://github.com/kyverno/policies/pod-security | kubectl apply -f -

kyverno-custom-pol:
	@echo ""
	@echo "Installing custom policies..."
	@echo ""
	kubectl apply -f kyverno-policies/add_labels.yaml
	kubectl apply -f kyverno-policies/add_netpol.yaml
	kubectl apply -f kyverno-policies/add_ns_quota.yaml
	kubectl apply -f kyverno-policies/patch_ns.yaml

all: kubectx argo-install kyverno-setup kyverno-reporting kyverno-policies kyverno-custom-pol