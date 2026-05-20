variable "libvirt_uri" {
  description = "libvirt connection URI"
  type        = string
  default     = "qemu:///system"
}

variable "ssh_public_key" {
  description = "Public SSH key for the 'ansible' user (required)"
  type        = string
}

variable "ubuntu_image_url" {
  description = "Cloud-image to base both VMs on"
  type        = string
  default     = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

variable "vm_memory" {
  description = "RAM in MiB for each VM"
  type        = number
  default     = 1024
}

variable "vm_vcpu" {
  description = "vCPUs for each VM"
  type        = number
  default     = 1
}

variable "vm_disk_size" {
  description = "Disk size for each VM in bytes (default 10 GiB)"
  type        = number
  default     = 10737418240
}

variable "libvirt_network" {
  description = "Existing libvirt network to attach the VMs to (default supplies DHCP)"
  type        = string
  default     = "default"
}

variable "inventory_path" {
  description = "Where to write the generated Ansible inventory"
  type        = string
  default     = "../ansible/inventory.ini"
}
