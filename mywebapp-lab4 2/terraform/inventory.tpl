[workers]
vm-worker ansible_host=${worker_ip}

[db]
vm-db ansible_host=${db_ip}

[all:vars]
ansible_user=ansible
ansible_ssh_common_args='-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null'
