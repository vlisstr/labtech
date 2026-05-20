#cloud-config
# Worker VM — nginx + mywebapp Node.js application.

hostname: vm-worker
manage_etc_hosts: true
preserve_hostname: false

users:
  - name: ansible
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true
    ssh_authorized_keys:
      - ${ssh_public_key}

  - name: teacher
    plain_text_passwd: '12345678'
    lock_passwd: false
    sudo: ALL=(ALL) ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}

ssh_pwauth: true

chpasswd:
  expire: false

package_update: true
package_upgrade: false
packages:
  - python3
  - python3-apt
