#!/bin/bash


#GET WKC CAMS asset 
#Works for data_asset also.

if [ "x$1" = "x" ] 
then
  echo
  echo "Usage: $0 <asset_id>"
  echo
  exit 1
fi


asset_id=$1
token=`./wkc_icp4d_gettoken.sh`
addr=`grep "^addr=" env_info.txt | cut -d= -f2 | sed -e 's/https\:\/\///'`
catalog_id=`grep "^wkc_catalog_id=" env_info.txt | cut -d= -f2`


curl -k -w "\n%{http_code}" -S -s -X GET \
            -H "Accept: application/json" \
            -H "Authorization: Bearer ${token}" \
"https://${addr}/v2/assets/${asset_id}?catalog_id=${catalog_id}" | {
    read body
    read code
    
    if [ "x$code" = "x200" ]
    then
      echo "$body" 
    else
      echo "ERROR:$code:$body"
    fi
}
