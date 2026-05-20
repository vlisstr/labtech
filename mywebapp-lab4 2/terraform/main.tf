# =============================================================================
# libvirt resources for Lab #4.
#
# We provision two VMs (vm-worker, vm-db) from a single Ubuntu 24.04
# cloud-image. Each VM gets its own cloud-init disk that creates an `ansible`
# user (SSH-only) and a `teacher` user (password 12345678). After apply,
# Terraform writes ../ansible/inventory.ini with the assigned IPs.
# =============================================================================

resource "libvirt_pool" "mywebapp" {
  name = "mywebapp-lab4"
  type = "dir"
  target {
    path = "/var/lib/libvirt/images/mywebapp-lab4"
  }
}

resource "libvirt_volume" "ubuntu_base" {
  name   = "ubuntu-24.04-base.qcow2"
  pool   = libvirt_pool.mywebapp.name
  source = var.ubuntu_image_url
  format = "qcow2"
}

# ----------------------------------------------------------------------------
# Worker VM
# ----------------------------------------------------------------------------
resource "libvirt_volume" "worker_disk" {
  name           = "worker.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.vm_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "worker_init" {
  name = "worker-cloudinit.iso"
  pool = libvirt_pool.mywebapp.name

  user_data = templatefile("${path.module}/cloud-init-worker.yml.tpl", {
    ssh_public_key = trimspace(var.ssh_public_key)
  })
}

resource "libvirt_domain" "worker" {
  name      = "vm-worker"
  memory    = var.vm_memory
  vcpu      = var.vm_vcpu
  cloudinit = libvirt_cloudinit_disk.worker_init.id

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# ----------------------------------------------------------------------------
# DB VM
# ----------------------------------------------------------------------------
resource "libvirt_volume" "db_disk" {
  name           = "db.qcow2"
  pool           = libvirt_pool.mywebapp.name
  base_volume_id = libvirt_volume.ubuntu_base.id
  size           = var.vm_disk_size
  format         = "qcow2"
}

resource "libvirt_cloudinit_disk" "db_init" {
  name = "db-cloudinit.iso"
  pool = libvirt_pool.mywebapp.name

  user_data = templatefile("${path.module}/cloud-init-db.yml.tpl", {
    ssh_public_key = trimspace(var.ssh_public_key)
  })
}

resource "libvirt_domain" "db" {
  name      = "vm-db"
  memory    = var.vm_memory
  vcpu      = var.vm_vcpu
  cloudinit = libvirt_cloudinit_disk.db_init.id

  network_interface {
    network_name   = var.libvirt_network
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db_disk.id
  }

  console {
    type        = "pty"
    target_type = "serial"
    target_port = "0"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }
}

# ----------------------------------------------------------------------------
# Ansible inventory — written after the VMs are up and have IPs.
# ----------------------------------------------------------------------------
resource "local_file" "ansible_inventory" {
  filename        = var.inventory_path
  file_permission = "0644"

  content = templatefile("${path.module}/inventory.tpl", {
    worker_ip = libvirt_domain.worker.network_interface[0].addresses[0]
    db_ip     = libvirt_domain.db.network_interface[0].addresses[0]
  })

  depends_on = [
    libvirt_domain.worker,
    libvirt_domain.db,
  ]
}
