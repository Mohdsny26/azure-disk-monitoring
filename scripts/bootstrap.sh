#!/bin/sh
# One-time setup, run by a cloud admin (not by Ansible).
# Usage: MG_ID=contoso-root CENTRAL_SUB=<sub-id> ALERT_EMAIL=ops@example.com sh scripts/bootstrap.sh
set -e
: "${MG_ID:?set MG_ID}"; : "${CENTRAL_SUB:?set CENTRAL_SUB}"; : "${ALERT_EMAIL:?set ALERT_EMAIL}"
LOC=${LOC:-centralindia}
RG=${RG:-rg-disk-monitoring}
MI_NAME=${MI_NAME:-id-ansible-disk-monitoring}

echo "1) Central resource group + resources"
az account set --subscription "$CENTRAL_SUB"
az group create -n "$RG" -l "$LOC" -o none
DCR_ID=$(az deployment group create -g "$RG" -f infra/main.bicep \
          -p alertEmail="$ALERT_EMAIL" --query properties.outputs.dcrId.value -o tsv)

echo "2) Managed identity for the Ansible control node (no passwords or secrets)"
az identity create -g "$RG" -n "$MI_NAME" -o none
MI_PRINCIPAL=$(az identity show -g "$RG" -n "$MI_NAME" --query principalId -o tsv)
echo "   Attach this identity to the Ansible control node VM: $MI_NAME"

echo "3) Custom least-privilege role at Management Group scope (inherited by all subscriptions)"
sed "s/__MG_ID__/$MG_ID/" infra/rbac-role.json > /tmp/rbac-role.json
az role definition create --role-definition /tmp/rbac-role.json -o none || echo "   (role already exists)"
sleep 30
az role assignment create --assignee-object-id "$MI_PRINCIPAL" --assignee-principal-type ServicePrincipal \
   --role "Disk Monitoring Operator" --scope "/providers/Microsoft.Management/managementGroups/$MG_ID" -o none
az role assignment create --assignee-object-id "$MI_PRINCIPAL" --assignee-principal-type ServicePrincipal \
   --role "Log Analytics Reader" --scope "/subscriptions/$CENTRAL_SUB/resourceGroups/$RG" -o none

echo "4) Azure Policy at Management Group (auto-enroll all current and new VMs)"
az deployment mg create -m "$MG_ID" -l "$LOC" -f infra/policy.bicep -p dcrId="$DCR_ID" -o none

echo "Done. DCR id: $DCR_ID"
echo "Put it in ansible/inventory/settings.yml (dcr_id)."
