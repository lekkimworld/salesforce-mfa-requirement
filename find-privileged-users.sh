#!/bin/bash
set -euo pipefail

read -rp "Enter the org alias to query: " ORG_ALIAS

if [[ -z "$ORG_ALIAS" ]]; then
    echo "Error: org alias cannot be empty" >&2
    exit 1
fi

echo ""
echo "Querying for privileged users in org: $ORG_ALIAS"
echo ""

# Step 1: Get User IDs with System Administrator profile
echo "Finding users with System Administrator profile..."
SYSADMIN_IDS=$(sf data query \
    --target-org "$ORG_ALIAS" \
    --query "SELECT Id FROM User WHERE Profile.Name = 'System Administrator' AND IsActive = true" \
    --json | jq -r '.result.records[].Id // empty')

# Step 2: Get Permission Set IDs that grant any of the target permissions
echo "Finding permission sets with elevated permissions..."
PS_IDS=$(sf data query \
    --target-org "$ORG_ALIAS" \
    --query "SELECT Id FROM PermissionSet WHERE IsOwnedByProfile = false AND (PermissionsModifyAllData = true OR PermissionsViewAllData = true OR PermissionsAuthorApex = true OR PermissionsCustomizeApplication = true)" \
    --json | jq -r '.result.records[].Id // empty')

# Step 3: Find Permission Set Groups that contain those permission sets
PSG_IDS=""
if [[ -n "$PS_IDS" ]]; then
    PS_ID_LIST=$(echo "$PS_IDS" | sed "s/^/'/;s/$/'/" | paste -sd, -)
    echo "Finding permission set groups containing those permission sets..."
    PSG_IDS=$(sf data query \
        --target-org "$ORG_ALIAS" \
        --query "SELECT PermissionSetGroupId FROM PermissionSetGroupComponent WHERE PermissionSetId IN ($PS_ID_LIST)" \
        --json | jq -r '.result.records[].PermissionSetGroupId // empty' | sort -u)
fi

# Step 4: Find users assigned to those permission sets or permission set groups
PS_USER_IDS=""
if [[ -n "$PS_IDS" ]]; then
    PS_ID_LIST=$(echo "$PS_IDS" | sed "s/^/'/;s/$/'/" | paste -sd, -)
    echo "Finding users assigned to elevated permission sets..."
    PS_USER_IDS=$(sf data query \
        --target-org "$ORG_ALIAS" \
        --query "SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId IN ($PS_ID_LIST) AND Assignee.IsActive = true" \
        --json | jq -r '.result.records[].AssigneeId // empty')
fi

PSG_USER_IDS=""
if [[ -n "$PSG_IDS" ]]; then
    PSG_ID_LIST=$(echo "$PSG_IDS" | sed "s/^/'/;s/$/'/" | paste -sd, -)
    echo "Finding users assigned to elevated permission set groups..."
    PSG_USER_IDS=$(sf data query \
        --target-org "$ORG_ALIAS" \
        --query "SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetGroupId IN ($PSG_ID_LIST) AND Assignee.IsActive = true" \
        --json | jq -r '.result.records[].AssigneeId // empty')
fi

# Step 5: Combine and deduplicate all user IDs
ALL_USER_IDS=$(printf '%s\n' $SYSADMIN_IDS $PS_USER_IDS $PSG_USER_IDS | sort -u | grep -v '^$')

if [[ -z "$ALL_USER_IDS" ]]; then
    echo ""
    echo "No privileged users found."
    exit 0
fi

# Step 6: Query user details
USER_ID_LIST=$(echo "$ALL_USER_IDS" | sed "s/^/'/;s/$/'/" | paste -sd, -)
echo "Fetching user details..."
echo ""

sf data query \
    --target-org "$ORG_ALIAS" \
    --query "SELECT Id, Name, Email FROM User WHERE Id IN ($USER_ID_LIST) ORDER BY Name"
