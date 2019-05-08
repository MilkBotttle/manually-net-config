# How to manually config compute network for nsx-trasport node

1. After Overcloud deploy complete
2. Edit `nsx_vars.yaml` with nsx config
3. Create inventory file run:
```
ansible-playbook create_inventory.yaml
```
4. Config compute:
```
ansible-playbook -i hosts config_compute.yaml --become -e "@nsx_vars.yaml"
```

5. After set trnsport node
```
ansible-playbook -i hosts start_patch.yaml --become
```

# Options in nsx_vars.yaml

* nsx_manager_vip: NSX manager's VIP
* thumbprint_manager_ip: Which manager get the thumbprint.
* nsx_username: NSX admin user name
* nsx_password: NSX admin user password
* nsx_thumbprint: Tumbprint for join host
* repo_file_url: Where to get the offline repo to install requirement package
