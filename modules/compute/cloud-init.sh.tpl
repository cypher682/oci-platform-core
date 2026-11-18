#!/bin/bash
# ─────────────────────────────────────────────
# Oracle Linux 9 bootstrap — base OS only.
# Ansible owns hardening, Docker, nginx and the app.
# ─────────────────────────────────────────────
set -euxo pipefail

hostnamectl set-hostname "${hostname}"

# Base tooling required by Ansible and OCI tooling
dnf -y makecache
dnf -y --setopt=install_weak_deps=False install \
  python3 \
  python3-pip \
  firewalld \
  chrony \
  tar \
  gzip \
  jq \
  git \
  curl \
  policycoreutils-python-utils

systemctl enable --now firewalld chrony

# Keep SELinux enforcing — hardening role verifies it
SELINUX_STATE=$(getenforce || true)
if [ "$SELINUX_STATE" != "Enforcing" ]; then
  setenforce 1 || true
fi

# Non-root automation user
if ! id deploy >/dev/null 2>&1; then
  useradd -m -s /bin/bash deploy
fi

install -d -m 0700 -o deploy -g deploy /home/deploy/.ssh
printf '%s\n' "${ssh_public_key}" > /home/deploy/.ssh/authorized_keys
chmod 0600 /home/deploy/.ssh/authorized_keys
chown deploy:deploy /home/deploy/.ssh/authorized_keys

printf 'deploy ALL=(ALL) NOPASSWD:ALL\n' > /etc/sudoers.d/90-deploy
chmod 0440 /etc/sudoers.d/90-deploy

# Bounded journal so a long sprint cannot fill the boot volume
install -d -m 0755 /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/limits.conf <<'EOF'
[Journal]
SystemMaxUse=512M
SystemMaxFileSize=64M
MaxRetentionSec=14day
EOF
systemctl restart systemd-journald

# Marker used by Ansible pre-flight checks
echo "cloud-init complete $(date -u +%FT%TZ)" > /var/log/platform-cloud-init.done
%{ if app_tier }
# Bootstrap health endpoint, appended only for the app tier so the load
# balancer can gate on /health before Ansible installs the real application.
dnf -y install nginx
cat > /usr/share/nginx/html/health <<'HEALTH'
{"status":"ok","tier":"app","served_by":"cloud-init"}
HEALTH
restorecon -Rv /usr/share/nginx/html >/dev/null 2>&1 || true
systemctl enable --now nginx
firewall-cmd --permanent --add-service=http >/dev/null
firewall-cmd --reload >/dev/null
%{ endif }