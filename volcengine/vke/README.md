## Get started
- use `terraform output -raw kubeconfig` to get kubeconfig

## Issues
- coredns addon can't be removed, use `terraform state rm volcengine_vke_addon.coredns` to remove from state
