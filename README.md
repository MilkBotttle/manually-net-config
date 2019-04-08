# How to manually config compute network for nsx-trasport node
1. When Stack deploy hooked.
2. Edit `compute-nic-config.yaml.j2` , `net-mapping.yaml` for suit, pxe network use {{ ctlplane_ip }} for each node, the value get from inventroy file.
3. Edit `nsx_vars.yaml` with nsx config
3. Create inventory file run:
```
ansible-playbook create_inventory.yaml
```
4. Config compute:
```
ansible-playbook -i hosts config_compute.yaml
```
