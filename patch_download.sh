#!/usr/bin/env bash

set -euo pipefail

FILE="patch.html"

export https_proxy=http://www-proxy.us.oracle.com:80
export http_proxy=http://www-proxy.us.oracle.com:80


read -p "Enter Patch Number , for example 38832610: " PATCH_NUMBER

read -p "Enter Email-ID (your-email@oracle.com): " EMAIL_ID
read -s -p "Enter password (your SSO Password): " PASSWORD


echo
echo "Patch Number : " $PATCH_NUMBER "and Email ID is :" $EMAIL_ID

echo "Downloading patch details for patch number $PATCH_NUMBER..."
curl -s -o $FILE -u $EMAIL_ID:$PASSWORD https://updates.oracle.com/ARULink/PatchDetails/process_form?patch_num=$PATCH_NUMBER

if grep -q "401 Authorization Required" "$FILE"; then
    echo "Error: 401 Authorization Required , user authentication failed. Please check your email ID and password."
    exit 1
fi


echo "Select a Release:"
echo "-------------------"

# Extract only the release select block
mapfile -t options < <(
  awk '
    /<select[[:space:]]+name=release/ { in_block=1; next }
    /<\/select>/ { in_block=0 }
    in_block && /<option/ { print }
  ' "$FILE" |
  sed -E 's/.*value="([^"]*)".*>(.*)/\1|\2/' |
  sed 's/[[:space:]]*$//'
)

# Validate extraction
if [ ${#options[@]} -eq 0 ]; then
    #echo "No other release options found!, Downloading the default patch for the release mentioned in ARU"
    ARU=$(grep -o 'name="aru" value="[0-9]*"' $FILE | awk -F'"' '{print $4}')
    PATCH_FILE=$(grep -o 'patch_file=p[^"&]*\.zip' $FILE | awk -F= '{print $2}')

#echo "Retrieved ARU: $ARU"
#echo "Retrieved PATCH_FILE: $PATCH_FILE"


    if [ -z "$ARU" ] || [ -z "$PATCH_FILE" ]; then
        echo "Failed to retrieve patch information. Please check the patch number and credentials."
        exit 1
    fi

    URL_DOWNLOAD_LINK="https://updates.oracle.com/Orion/Services/download/${PATCH_FILE}?aru=${ARU}&patch_file=${PATCH_FILE}"

    echo "Downloading from URL: "
    echo "$URL_DOWNLOAD_LINK"

    curl -L -u "$EMAIL_ID:$PASSWORD"   -o "$PATCH_FILE"  "$URL_DOWNLOAD_LINK"
        exit 1
fi

# Display menu
for i in "${!options[@]}"; do
    value="${options[$i]%%|*}"
    text="${options[$i]##*|}"
    printf "%d) %s\n" $((i+1)) "$text"
done

echo
read -p "Enter choice number: " choice

index=$((choice-1))

if [[ -n "${options[$index]}" ]]; then
    value="${options[$index]%%|*}"
    text="${options[$index]##*|}"

    echo
    echo "You selected:"
    echo "Text  : $text"
    echo "Value : $value"
    URL_DOWNLOAD_LINK2="https://updates.oracle.com/Orion/PatchDetails/handle_rel_change?release=$value&patch_num=$PATCH_NUMBER"
    echo "URL for selected release: $URL_DOWNLOAD_LINK2"
    curl -s -L -u "$EMAIL_ID:$PASSWORD"   -o "$FILE"  "$URL_DOWNLOAD_LINK2"

    ARU=$(grep -o 'name="aru" value="[0-9]*"' $FILE | awk -F'"' '{print $4}')
    PATCH_FILE=$(grep -o 'patch_file=p[^"&]*\.zip' $FILE | awk -F= '{print $2}')

#echo "Retrieved ARU: $ARU"
#echo "Retrieved PATCH_FILE: $PATCH_FILE"


    if [ -z "$ARU" ] || [ -z "$PATCH_FILE" ]; then
        echo "Failed to retrieve patch information. Please check the patch number and credentials."
        exit 1
    fi

    URL_DOWNLOAD_LINK3="https://updates.oracle.com/Orion/Services/download/${PATCH_FILE}?aru=${ARU}&patch_file=${PATCH_FILE}"

    echo "Downloading from URL: $URL_DOWNLOAD_LINK3"
    
    curl -L -u "$EMAIL_ID:$PASSWORD"   -o "$PATCH_FILE"  "$URL_DOWNLOAD_LINK3"
    
    #rm -f $FILE
    exit 0
    
else
    echo "Invalid selection"
    exit 1
fi
