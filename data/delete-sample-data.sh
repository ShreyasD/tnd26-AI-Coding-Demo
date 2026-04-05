#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <target-org-alias>"
  exit 1
fi

ORG="$1"

BROKER_EMAILS="'caroline@dreamhouse.demo','michael@dreamhouse.demo','jonathan@dreamhouse.demo','jen@dreamhouse.demo','olivia@dreamhouse.demo','miriam@dreamhouse.demo','michelle@dreamhouse.demo','victor@dreamhouse.demo'"
BROKER_CONTACT_EMAILS="$BROKER_EMAILS"
CONTACT_EMAILS="'bholmes@goodmail.com','leslie@pentagon.com','julywalker@brain.com','annaj@mymail.com','jconnor@goodmail.com'"
TMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

delete_by_query() {
  local sobject="$1"
  local query="$2"
  local output_file="$TMP_DIR/${sobject}.csv"

  sf data query \
    --target-org "$ORG" \
    --query "$query" \
    --result-format csv \
    --output-file "$output_file" >/dev/null

  if [[ ! -s "$output_file" ]] || [[ $(wc -l < "$output_file") -le 1 ]]; then
    echo "No ${sobject} records found to delete."
    return
  fi

  sf data delete bulk \
    --target-org "$ORG" \
    --sobject "$sobject" \
    --file "$output_file" \
    --wait 10
}

delete_by_query "Property__c" "SELECT Id FROM Property__c WHERE Broker__r.Email__c IN ($BROKER_EMAILS)"
delete_by_query "Broker__c" "SELECT Id FROM Broker__c WHERE Email__c IN ($BROKER_EMAILS)"
delete_by_query "Contact" "SELECT Id FROM Contact WHERE Email IN ($BROKER_CONTACT_EMAILS)"
delete_by_query "Contact" "SELECT Id FROM Contact WHERE Email IN ($CONTACT_EMAILS)"

echo "Sample data deletion submitted for org: $ORG"
