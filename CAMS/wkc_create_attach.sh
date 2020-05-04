#!/bin/bash

#Create WKC CAMS attachment

if [ "x$1" = "x"  -o "x$2" = "x" -o "x$3" = "x" ]
then
  echo
  echo "Usage: $0 <data_asset_ID> <attach_name> <CSV file path>"
  exit 1
fi

data_asset_ID=$1
attach_name=$2
filePath=$3
token=`./wkc_icp4d_gettoken.sh`
addr=`grep "^addr=" env_info.txt | cut -d= -f2 | sed -e 's/https\:\/\///'`
catalog_id=`grep "^wkc_catalog_id=" env_info.txt | cut -d= -f2`

#create attachment
read -r url1 attachment_id <<<$(curl -k -w "\n%{http_code}" -S -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $token" \
-d "{
          \"name\": \"${attach_name}\",
          \"description\": \"WKC attachment test\",
          \"asset_type\": \"data_asset\",
          \"mime\":\"text/csv\",
          \"data_partitions\": 1 }" \
    "https://${addr}/v2/assets/${data_asset_ID}/attachments?catalog_id=${catalog_id}"  | {
    read body
    read code
    
    if [ "x$code" = "x201" ]
    then
      url1=`echo $body | awk -F'{"|":"|","|":["|"],"|"}|,"' '{for(i=1;i<=NF;i++)if($i=="url1")print $(i+1)}'`
      attachment_id=`echo $body | awk -F'{"|":"|","|":["|"],"|"}|,"' '{for(i=1;i<=NF;i++)if($i=="attachment_id")print $(i+1)}'`
      echo "$url1" 
      echo "$attachment_id" 
    else
      echo "ERROR:$code:$body"
    fi
}
)

#upload csv file
echo "https://${addr}${url1}" 

curl -k -X PUT "https://${addr}${url1}"  -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "file=@${filePath}"  | {
    read body
    read code
    echo "$code:$body"
}

#complete attachment



curl -k -w "\n%{http_code}" -S -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: Bearer $token" \
    "https://${addr}/v2/assets/${data_asset_ID}/attachments/${attachment_id}/complete?catalog_id=${catalog_id}"  | {
    read body
    read code
    
    if [ "x$code" = "x200" ]
    then
      echo "succeed:$code:$body" 
    else
      echo "ERROR:$code:$body"
    fi
}
