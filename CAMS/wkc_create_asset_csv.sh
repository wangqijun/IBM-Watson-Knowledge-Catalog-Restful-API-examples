#!/bin/bash

#Create WKC CAMS asset

if [ "x$1" = "x" ]
then
  echo
  echo "Usage: $0 <data_asset_name>"
  exit 1
fi

data_asset_name=$1
token=`./wkc_icp4d_gettoken.sh`
addr=`grep "^addr=" env_info.txt | cut -d= -f2 | sed -e 's/https\:\/\///'`
catalog_id=`grep "^wkc_catalog_id=" env_info.txt | cut -d= -f2`


#create data asset
curl -k -w "\n%{http_code}" -S -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $token" \
-d "{
    \"metadata\": {
          \"name\": \"${data_asset_name}\",
          \"description\": \"WKC eventmapper test\",
          \"asset_type\": \"data_asset\",
          \"origin_country\": \"us\",
          \"rating\": 0,
          \"rov\": {
               \"mode\": 0
          },
          \"asset_category\": \"USER\"
         },
     \"entity\": {\"data_asset\":{\"mime_type\":\"text/csv\",\"dataset\":true}}}" \
    "https://${addr}/v2/data_assets?catalog_id=${catalog_id}"  | {
    read body
    read code
    
    if [ "x$code" = "x201" ]
    then
      asset_id=`echo $body | awk -F'{"|":"|","|":["|"],"|"}' '{for(i=1;i<=NF;i++)if($i=="asset_id")print $(i+1)}'`
      echo "$asset_id" 
    else
      echo "ERROR:$code:$body"
    fi
}
