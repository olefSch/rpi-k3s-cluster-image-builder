set dotenv-load

default:
    @just --list

lint:
    pre-commit run --all-files

clean:
    @echo "Lets clean it up!! :)"
    rm -rf workspace/
    rm -rf cloud-init/network-config
    rm -rf cloud-init/user-data
    rm -rf manifests/argocd-app.yaml
    rm -rf manifests/kube-vip-daemonset.yaml
    @echo "Cleaned ..."

build-locally:
    @echo "Spinning up a privileged Linux container to build the image..."
    docker run --rm -it --privileged \
        --env-file .env \
        -v "$(pwd):/workspace" \
        -w /workspace \
        ubuntu:24.04 \
        bash -c "apt-get update && apt-get install -y sudo curl xz-utils kpartx gettext-base \
        && echo 'Injecting secrets via envsubst...' \
        && envsubst < cloud-init/user-data.yaml.tftpl > cloud-init/user-data \
        && envsubst < cloud-init/network-config.yaml.tftpl > cloud-init/network-config \
        && envsubst < manifests/argocd-app.yaml.tftpl > manifests/argocd-app.yaml \
        && envsubst < manifests/kube-vip-daemonset.yaml.tftpl > manifests/kube-vip-daemonset.yaml \
        && echo 'Running build script...' \
        && bash scripts/build-image.sh"

test-pipeline:
    @echo "Running GitHub Action via act (Requires sudo for Docker privileged mode)..."
    act workflow_dispatch \
        --container-architecture linux/amd64 \
        --container-options "--privileged" \
        --secret-file .secrets \
        --input node_role=master-init \
        --input node_hostname=k3s-act-test \
        --input node_ip=192.168.1.100 \
        --input vip_ip=192.168.1.99
