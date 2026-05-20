# How to run

Цей документ — детальна покрокова інструкція з типовими помилками.

## 0. Базові передумови

Хост — Linux з KVM. Якщо ви на macOS чи Windows — підніміть локально віртуалку з Ubuntu Server 24.04 (через VirtualBox / UTM) або винесіть лабу на хмарну Linux-машину з підтримкою nested virtualization (Hetzner CCX-серія, GCP n2 з `enable-nested-virtualization`).

## 1. Встановлення тулчейну (Ubuntu 24.04)

```bash
sudo apt update
sudo apt install -y \
    qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils virtinst \
    cloud-image-utils \
    python3-pip python3-libvirt \
    ansible

# Terraform не в APT — додаємо HashiCorp репозиторій:
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform

sudo usermod -aG libvirt $USER
sudo usermod -aG kvm $USER
# вийдіть з shell-у і знову зайдіть, або: newgrp libvirt

# колекції Ansible (модулі ufw / mysql / npm):
ansible-galaxy collection install community.general community.mysql
```

Перевірка готовності:

```bash
terraform version
ansible --version
virsh list --all
virsh net-list --all          # має бути активна мережа 'default'
```

Якщо мережі `default` немає або вона неактивна:

```bash
sudo virsh net-start default
sudo virsh net-autostart default
```

## 2. Підготовка SSH-ключа

Терраформ потребує ваш публічний ключ для cloud-init:

```bash
# Якщо у вас ще немає ключа:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""

cat ~/.ssh/id_ed25519.pub
# скопіюйте цей рядок цілком (починається з "ssh-ed25519")
```

## 3. Запуск Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# відредагуйте terraform.tfvars: вставте свій ssh_public_key

terraform init
terraform plan         # подивіться, що буде створено
terraform apply        # підтвердіть "yes"
```

Перший `terraform init` завантажить provider libvirt (~50 МБ). Перший `terraform apply` стягне Ubuntu cloud-image (~700 МБ) — це найдовша частина.

В результаті:
- 2 ВМ запущені (можна побачити: `virsh list`)
- файл `../ansible/inventory.ini` створений з реальними IP-адресами
- виведено `worker_ip`, `db_ip`, `inventory_path`

## 4. Запуск Ansible

```bash
cd ../ansible
ansible-playbook playbook.yml
```

Playbook:
1. чекає поки SSH буде доступний на обох ВМ
2. на обох ставить `teacher` user (sudo з паролем)
3. на vm-db ставить MariaDB, налаштовує bind на свою IP, відкриває порт 3306 у UFW тільки для worker IP, створює БД і користувача mywebapp
4. на vm-worker ставить Node.js, копіює код, ставить залежності, генерує systemd-юніт з template (з підстановкою db_host = IP vm-db), запускає міграцію, стартує застосунок
5. на vm-worker ставить nginx з конфігом, відкриває порт 80 у UFW
6. створює operator user з обмеженим sudo

Усе має пройти за 3-7 хвилин (залежно від швидкості apt і npm install).

## 5. Перевірка

```bash
cd terraform
WORKER_IP=$(terraform output -raw worker_ip)
DB_IP=$(terraform output -raw db_ip)
echo "worker: $WORKER_IP   db: $DB_IP"

# nginx віддає
curl http://$WORKER_IP/
curl -H 'Accept: application/json' http://$WORKER_IP/items

# /items POST + GET cycle
curl -X POST -d 'name=hammer&quantity=3' \
     -H 'Accept: application/json' http://$WORKER_IP/items
curl -H 'Accept: application/json' http://$WORKER_IP/items

# Health не назовні (повинен бути 404):
curl -i http://$WORKER_IP/health/alive

# БД ззовні недоступна:
nc -zvw3 $DB_IP 3306       # → no route to host / connection refused / timeout
```

## 6. Перевірка ідемпотентності

```bash
ansible-playbook playbook.yml
# в кінці має бути: changed=0  для усих хостів
```

## 7. Прибирання

```bash
cd terraform
terraform destroy
# обидві ВМ, диски, мережеві ресурси видаляються
```

## Типові помилки

**`Error: Could not connect to libvirt`** — користувач не в групі libvirt, або демон не запущений:
```bash
sudo systemctl status libvirtd
groups $USER       # має містити 'libvirt'
```

**`Error: error creating storage pool 'mywebapp-lab4': storage volume ... already exists`** — лишилися ресурси від попередньої спроби. Очистити:
```bash
sudo virsh pool-destroy mywebapp-lab4
sudo virsh pool-undefine mywebapp-lab4
sudo rm -rf /var/lib/libvirt/images/mywebapp-lab4
```

**`UNREACHABLE: ssh: connect to host ... port 22: No route to host`** в Ansible — ВМ ще не повністю завантажилася, або у вас VPN/iptables втручається. Спробуйте `ping <worker_ip>` спочатку.

**Ansible падає на `community.mysql.mysql_db: No module named pymysql`** — на vm-db не встановився python3-pymysql. Запустіть playbook ще раз; перший таск role `db` його ставить.

**`npm install` falls with EACCES** — не вистачає прав на /opt/mywebapp. Перевірити, що owner = `app` user.

**ВМ зʼявились але `ansible-playbook` каже UNREACHABLE** — cloud-init ще не догодившись. Зачекайте 1-2 хвилини і запустіть playbook знову — він ідемпотентний.

**Migration падає з ER_CONNECTION_REFUSED** — MariaDB ще не перезавантажилася з новим bind-address. Зачекайте і запустіть playbook знову.

**UFW заблокував SSH** — на db VM playbook міг зробити `ufw enable` ДО `allow OpenSSH`. Тому в common-ролі `allow OpenSSH` йде ПЕРЕД UFW enable у db-ролі. Якщо все ж застрягли — підключіться через `virsh console vm-db`, увійдіть як ansible і виправте через `sudo ufw allow OpenSSH`.
