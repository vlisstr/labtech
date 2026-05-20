# Лабораторна робота №4 — IaC: Terraform + Ansible

Багатовузлове розгортання застосунку з Лаб №1 у двох ВМ:
- **vm-worker** — nginx (reverse proxy) + Node.js застосунок
- **vm-db** — MariaDB, доступна лише з worker

```
client → nginx :80 → mywebapp 127.0.0.1:5200 → MariaDB <vm-db-ip>:3306
        ╰──────── vm-worker ────────╯       ╰── vm-db ──╯
```

## 1. Варіант

N = 26 → V2 = 1, V3 = 3, V5 = 2 → **Simple Inventory**, **MariaDB**, **порт 5200**, конфігурація через **CLI-аргументи** (передаються через systemd-юніт, який Ansible генерує з шаблону).

## 2. Вимоги до хоста, на якому запускається IaC

**Linux** з підтримкою KVM. Я використовував Ubuntu 24.04, але підійде будь-який сучасний дистрибутив. На macOS / Windows libvirt не запускається — для запуску цієї лаби локально потрібна Linux-машина (фізична або хмарна).

Встановлені пакети (приклад для Ubuntu 24.04):

```bash
sudo apt update
sudo apt install -y \
    qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
    terraform ansible \
    python3-pip python3-libvirt
sudo usermod -aG libvirt $USER
# log out and back in for group change to apply
```

Якщо `terraform` немає в APT — встанови з [офіційних інструкцій HashiCorp](https://developer.hashicorp.com/terraform/install).

Перевірка:

```bash
virsh list --all                    # libvirt запустився
terraform version                    # >= 1.5
ansible --version                    # >= 2.14
ansible-galaxy collection install community.general community.mysql
```

## 3. Запуск

Дві команди:

```bash
# 1) інфраструктура — 2 ВМ
cd terraform
cp terraform.tfvars.example terraform.tfvars
# відредагуй terraform.tfvars: встав свій SSH публічний ключ
terraform init
terraform apply

# 2) конфігурація — застосунок, БД, nginx, користувачі
cd ../ansible
ansible-playbook playbook.yml
```

`terraform apply` піднімає 2 ВМ із cloud-init (створює користувачів `ansible` та `teacher`) і записує `ansible/inventory.ini` з IP-адресами. `ansible-playbook` далі сам конфігурує все решта.

## 4. Перевірка

```bash
# IP-адреси:
cd terraform && terraform output

# Базова перевірка через nginx (з вашої машини):
curl http://<worker_ip>/
curl -H 'Accept: application/json' http://<worker_ip>/items

# Health (з worker, локально — не назовні):
ssh ansible@<worker_ip> 'curl -s http://127.0.0.1:5200/health/alive'
ssh ansible@<worker_ip> 'curl -s http://127.0.0.1:5200/health/ready'

# Перевірка ізоляції БД:
# З worker — працює:
ssh ansible@<worker_ip> 'nc -zv <db_ip> 3306'
# З вашої машини — нє:
nc -vz <db_ip> 3306        # повинно бути timeout або refused

# Користувачі:
ssh teacher@<worker_ip>     # пароль 12345678
ssh operator@<worker_ip>    # пароль 12345678
ssh teacher@<db_ip>         # пароль 12345678

# Operator: дозволено лише management mywebapp + reload nginx
ssh operator@<worker_ip>
$ sudo systemctl restart mywebapp     # OK
$ sudo systemctl reload nginx          # OK
$ sudo systemctl stop mariadb          # ЗАБОРОНЕНО (mariadb на іншій ВМ; тут і так нема)
$ sudo cat /etc/shadow                 # ЗАБОРОНЕНО

# Gradebook:
ssh teacher@<worker_ip> 'cat /home/student/gradebook'   # → 26
```

## 5. Ідемпотентність

Повторний `ansible-playbook playbook.yml` повинен вивести `ok=N changed=0 ...`. Всі модулі (`apt`, `user`, `template`, `systemd`, `mysql_db`, `mysql_user`, `ufw`) ідемпотентні; єдина команда (`migrate.js` через `ansible.builtin.command`) явно позначена `changed_when: false`, бо скрипт міграції сам ідемпотентний (`CREATE TABLE IF NOT EXISTS`, `SHOW INDEX` перед `CREATE INDEX`).

## 6. Структура репозиторію

```
.
├── README.md                        ← цей файл
├── docs/
│   └── architecture.md              ← деталі архітектури і потоку даних
├── terraform/
│   ├── versions.tf                  ← provider libvirt
│   ├── variables.tf                 ← змінні (ssh_public_key обовʼязковий)
│   ├── main.tf                      ← pool, ubuntu base image, 2 ВМ, inventory
│   ├── outputs.tf                   ← worker_ip, db_ip, inventory_path
│   ├── cloud-init-worker.yml.tpl    ← cloud-init для vm-worker
│   ├── cloud-init-db.yml.tpl        ← cloud-init для vm-db
│   ├── inventory.tpl                ← шаблон для генерації ansible inventory
│   └── terraform.tfvars.example     ← скопіювати → terraform.tfvars
└── ansible/
    ├── ansible.cfg
    ├── playbook.yml                 ← єдина точка входу
    ├── group_vars/{all,db,workers}.yml
    └── roles/
        ├── common/                  ← teacher user, base packages, UFW SSH
        ├── db/                      ← MariaDB, bind + UFW обмеження, DB+user
        ├── worker_app/              ← Node.js, app, systemd unit, app+operator users
        │   └── files/app/            ← код застосунку (Lab 1 без змін)
        └── worker_nginx/             ← nginx config + UFW :80
```

## 7. Користувачі

| Користувач | Де | Як заходити | Права |
|---|---|---|---|
| `ansible` | усі ВМ | SSH-ключ (з cloud-init) | NOPASSWD sudo |
| `teacher` | усі ВМ | пароль `12345678` | sudo з паролем |
| `app`     | worker | nologin (system user) | мінімальні |
| `operator`| worker | пароль `12345678` | sudo тільки на 4 systemctl команди для mywebapp + reload nginx |

## 8. Якщо щось пішло не так

Див. `docs/how-to-run.md` для покрокової інструкції з типовими помилками.
