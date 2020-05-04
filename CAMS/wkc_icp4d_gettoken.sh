#!/bin/bash

#Returns WKC icp4d user Bearer accessToken

addr=`grep "^addr=" env_info.txt | cut -d= -f2 | sed -e 's/https\:\/\///'`
user=`grep "^wkc_user=" env_info.txt | cut -d= -f2`
password=`grep "^wkc_password=" env_info.txt | cut -d= -f2`


curl -s -k -X GET \
 -H "Cache-Control: no-cache" \
 -H "Content-Type: application/json" \
 -H "Postman-Token: 4a575846-eda3-4d47-b52b-4a74ef457f22" \
 -H "username: $user" \
 -H "password: $password" \
"https://${addr}/v1/preauth/validateAuth" | awk -F'{"|":"|","|":["|"],"|"}' '{for(i=1;i<=NF;i++)if($i=="accessToken")print $(i+1)}'



