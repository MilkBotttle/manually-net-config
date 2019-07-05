# How to manually config compute network for nsx-trasport node
1. When overcloud deploy complete
2. Edit `nsx_vars.yaml` with nsx config
3. Create inventory file run:
```
tripleo-ansible-inventory \
  --config-file ansible.cfg \
  --ansible_ssh_user heat-admin \
  --stack rockycloud \
  --static-yaml-inventory inventory.yaml
```
4. Check need add to NSX-T host are current
This will list nodes name check they are current
```
ansible-playbook -i inventory.yaml list-need-configure-nodes.yaml
```
6. If need static route edit `set_static_route.yaml` than play
```
ansible-playbook -i inventory.yaml set_static_route.yaml --become
```
5. Config compute to NSX-T host:
```
ansible-playbook -i inventory.yaml config_compute.yaml --become
```
5. Add transport node
```
ansible-playbook -i inventory.yaml add_ts.yaml
```
6. After set trnsport node start ovs patch and set mtu
```
ansible-playbook -i inventory.yaml start_patch.yaml --become
```
