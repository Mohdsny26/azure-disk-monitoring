#!/bin/sh
echo "AZ $*" >> ${TMPDIR:-/tmp}/az_calls.log
case "$*" in
  *"summarize vms"*) echo '{"count":2,"data":[{"subscriptionId":"sub-aaa","vms":12},{"subscriptionId":"sub-bbb","vms":7}]}' ;;
  *"leftouter"*) echo '{"count":2,"data":[{"id":"/subscriptions/sub-aaa/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-web1","name":"vm-web1","subscriptionId":"sub-aaa","resourceGroup":"rg1","location":"centralindia"},{"id":"/subscriptions/sub-bbb/resourceGroups/rg2/providers/Microsoft.Compute/virtualMachines/vm-db1","name":"vm-db1","subscriptionId":"sub-bbb","resourceGroup":"rg2","location":"eastus"}]}' ;;
  "graph query"*) echo '{"count":2,"data":[{"id":"/subscriptions/sub-aaa/resourceGroups/rg1/providers/Microsoft.Compute/virtualMachines/vm-web1","name":"vm-web1","subscriptionId":"sub-aaa","resourceGroup":"rg1","location":"centralindia"},{"id":"/subscriptions/sub-bbb/resourceGroups/rg2/providers/Microsoft.Compute/virtualMachines/vm-db1","name":"vm-db1","subscriptionId":"sub-bbb","resourceGroup":"rg2","location":"eastus"}]}' ;;
  *"run-command invoke"*vm-web1*) printf '[stdout]\n/dev/sda1  30G  27G  3G  91%% /data\n[stderr]\n' ;;
  *"run-command invoke"*) printf '[stdout]\n\n[stderr]\n' ;;
  *"workspace show"*) echo "11111111-2222-3333-4444-555555555555" ;;
  *"log-analytics query"*) echo '[{"Computer":"vm-web1","InstanceName":"/data","UsedPct":91.2},{"Computer":"vm-db1","InstanceName":"/","UsedPct":83.5}]' ;;
  *) : ;;
esac
