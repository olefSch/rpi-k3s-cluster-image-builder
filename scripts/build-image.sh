#!/bin/bash
set -e

UBUNTU_URL="https://cdimage.ubuntu.com/releases/26.04/release/ubuntu-26.04-preinstalled-server-arm64+raspi.img.xz"
WORKSPACE="workspace"
IMG_NAME="ubuntu-custom.img"
IMG_PATH="$WORKSPACE/$IMG_NAME"
MOUNT_DIR=$(mktemp -d)

cleanup() {
  echo "Running cleanup..."
  if mountpoint -q "$MOUNT_DIR"; then
    sudo umount "$MOUNT_DIR"
  fi
  if [ -n "$LOOP_DEV" ]; then
    # Delete the partition mappings first
    sudo kpartx -dv "$LOOP_DEV" || true
    # Then detach the loop device
    sudo losetup -d "$LOOP_DEV" || true
  fi
  rm -rf "$MOUNT_DIR"
}
trap cleanup EXIT ERR INT TERM

mkdir -p "$WORKSPACE"

if [ ! -f "$WORKSPACE/ubuntu.img.xz" ]; then
  echo "Downloading Ubuntu image..."
  curl -sL "$UBUNTU_URL" -o "$WORKSPACE/ubuntu.img.xz"
else
  echo "Ubuntu image already downloaded, skipping..."
fi

echo "Extracting original image..."
xz -d -c "$WORKSPACE/ubuntu.img.xz" >"$IMG_PATH"

echo "Mounting image boot partition..."
LOOP_DEV=$(sudo losetup -f --show "$IMG_PATH")
LOOP_NAME=$(basename "$LOOP_DEV") # e.g., "loop0"

sudo kpartx -av "$LOOP_DEV"

sleep 2

sudo mount "/dev/mapper/${LOOP_NAME}p1" "$MOUNT_DIR"

echo "Injecting SSD/USB boot fixes..."
echo "usb_max_current_enable=1" | sudo tee -a "$MOUNT_DIR/config.txt" >/dev/null

echo "Injecting cloud-init files..."
sudo cp cloud-init/user-data "$MOUNT_DIR/user-data"
sudo cp cloud-init/network-config "$MOUNT_DIR/network-config"

echo "Staging auto-deploy manifests..."
sudo mkdir -p "$MOUNT_DIR/k3s-manifests"
sudo cp manifests/argocd-helm.yaml "$MOUNT_DIR/k3s-manifests/"
sudo cp manifests/argocd-app.yaml "$MOUNT_DIR/k3s-manifests/"
sudo cp manifests/kube-vip-daemonset.yaml "$MOUNT_DIR/k3s-manifests/"

echo "Unmounting image..."
sudo umount "$MOUNT_DIR"
sudo kpartx -dv "$LOOP_DEV"
sudo losetup -d "$LOOP_DEV"
LOOP_DEV=""
MOUNT_DIR=""

echo "Compressing final custom image..."
xz -z -T0 "$IMG_PATH"

echo "Build complete! Artifact ready at ${IMG_PATH}.xz"
