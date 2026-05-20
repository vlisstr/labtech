output "worker_ip" {
  description = "IP address of the worker VM (nginx + web app)"
  value       = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  description = "IP address of the database VM"
  value       = libvirt_domain.db.network_interface[0].addresses[0]
}

output "inventory_path" {
  description = "Generated Ansible inventory location"
  value       = local_file.ansible_inventory.filename
}

output "next_step" {
  description = "Command to run Ansible against the new infrastructure"
  value       = "cd ../ansible && ansible-playbook playbook.yml"
}
