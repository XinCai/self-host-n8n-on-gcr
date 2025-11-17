#!/bin/bash
# Cloud SQL Optimization Checker
# Requires: gcloud, jq

PROJECT=$(gcloud config get-value project)
echo "🔍 Checking Cloud SQL instances in project: $PROJECT"
echo "-------------------------------------------"

instances=$(gcloud sql instances list --format="json")

if [[ -z "$instances" || "$instances" == "[]" ]]; then
  echo "❌ No Cloud SQL instances found."
  exit 0
fi

echo "$instances" | jq -c '.[]' | while read -r instance; do
  NAME=$(echo $instance | jq -r '.name')
  TIER=$(echo $instance | jq -r '.settings.tier')
  REGION=$(echo $instance | jq -r '.region')
  STATE=$(echo $instance | jq -r '.state')
  STORAGE_TYPE=$(echo $instance | jq -r '.settings.dataDiskType')
  STORAGE_SIZE=$(echo $instance | jq -r '.settings.dataDiskSizeGb')
  BACKUPS_ENABLED=$(echo $instance | jq -r '.settings.backupConfiguration.enabled')
  ACTIVATION_POLICY=$(echo $instance | jq -r '.settings.activationPolicy')

  echo "📦 Instance: $NAME"
  echo "   Tier: $TIER | Region: $REGION | Status: $STATE"
  echo "   Storage: $STORAGE_SIZE GB ($STORAGE_TYPE)"
  echo "   Backups enabled: $BACKUPS_ENABLED | Activation policy: $ACTIVATION_POLICY"

  # 💡 Recommendations
  if [[ "$STATE" == "RUNNABLE" && "$ACTIVATION_POLICY" == "ALWAYS" ]]; then
    echo "   👉 Consider stopping this instance when not in use (activation-policy=NEVER)."
  fi

  if [[ "$TIER" == *"db-n1-standard"* || "$TIER" == *"db-n1-highmem"* ]]; then
    echo "   👉 Instance uses N1 machine family. Switching to custom tiers (db-custom) may be cheaper."
  fi

  if [[ "$TIER" == *"db-custom"* ]]; then
    vcpu=$(echo $TIER | cut -d'-' -f3)
    mem=$(echo $TIER | cut -d'-' -f4)
    if (( vcpu > 2 )); then
      echo "   👉 Check CPU usage: this has $vcpu vCPUs. Might be oversized."
    fi
    if (( mem > 8192 )); then
      echo "   👉 Check memory usage: this has $mem MB. Could be oversized."
    fi
  fi

  if [[ "$STORAGE_TYPE" == "PD_SSD" && "$STATE" == "RUNNABLE" ]]; then
    echo "   👉 SSD storage is more expensive. Switch to HDD if performance allows."
  fi

  if [[ "$BACKUPS_ENABLED" == "true" ]]; then
    echo "   👉 Review backup retention. Too many backups increase storage costs."
  else
    echo "   ✅ Backups disabled (no backup storage cost)."
  fi

  echo "-------------------------------------------"
done
