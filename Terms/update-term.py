import os
import sys
import requests, json

with open(sys.argv[1]) as json_file:
    data = json.load(json_file)

username = data["username"]
password = data["password"]
updateFile = data["updateFile"]
customAttCnt = data["customAttCnt"]

# Get access token
def GetToken():
    url_getToken = data["URL"]+"/v1/preauth/validateAuth"
    headers_obj={"cache-control": "no-cache", "content-type": "application/json","username":username,"password":password}
    response = requests.get(url_getToken,  headers=headers_obj,verify=False)
    accessToken = response.json()['accessToken']
    print(accessToken)
    return accessToken


# Get all the terms
def GetTermsCnt(token):
    url_getTerms = data["URL"]+"//v3/glossary_terms"
    headers_obj={"X-OpenID-Connect-ID-Token": "Bearer", "Accept": "application/json", "Authorization":"Bearer "+token}
    response = requests.get(url_getTerms,headers=headers_obj,verify=False)
    responseJson=response.json()
    #print json.dumps(responseJson, indent=2, sort_keys=True)
    termCnt = responseJson['count']
    return termCnt

# Get all the terms
def GetTerms(token,offset):
    url_getTerms = data["URL"]+"//v3/glossary_terms?offset="+str(offset)+"&limit=200"

    headers_obj={"X-OpenID-Connect-ID-Token": "Bearer", "Accept": "application/json", "Authorization":"Bearer "+token}
    response = requests.get(url_getTerms,headers=headers_obj,verify=False)
    responseJson=response.json()
    print json.dumps(responseJson, indent=2, sort_keys=True)
    termCnt = responseJson['count']
    print("TermCnt = " + str(termCnt) )
    terms = []

    if (offset + 200) > termCnt:
       batchSize = termCnt - offset
    else:
       batchSize = 200


    for i in range(0,batchSize):
    #for i in range(0,30):
      print("Index I = " + str(i) )
      #print("responseJson = " + str(responseJson) )
      terms.append({"name":responseJson["resources"][i]["metadata"]["name"],"artifact_id":responseJson["resources"][i]["metadata"]["artifact_id"],"version_id":responseJson["resources"][i]["metadata"]["version_id"],"customAtt":responseJson["resources"][i]["entity"]["custom_attributes"]})
    print(terms)
    return terms

## get update custom attribute value from csv file
def getUpdateValue(updateFile):

    with open(updateFile,'r') as csv_file:
      lines = csv_file.readlines()

    termName = []
    customAttValueList = []
    for i in range(0,customAttCnt):
         customAttValueList.append([])
    for line in lines:
      data = line.split(',')
      print("CVS DATA**********************************")
      print(data)
      #termName.append(data[0])
      termName.append(data[0].decode('utf-8','ignore').encode("utf-8").replace('"', ''))
      for i in range(0,customAttCnt):
         customAttValueList[i].append(data[i+1].decode('utf-8','ignore').encode("utf-8").rstrip())
    return termName,customAttValueList

## update custom attribute value
def patchUpdate(terms, updateTermName,customAttValueList,token):

    print("Start patchUpdate term is in the update list************")
    #print(terms)
    print("update list************")
    print(updateTermName)
    print("END patchUpdate term is in the update list************")
    for term in terms:
      #print( term["name"] )
      if term["name"] in updateTermName:
        print("term is in the update list************")
        print(term)
        index = updateTermName.index(term["name"])
        url_patch = data["URL"]+"/v3/glossary_terms/"+term["artifact_id"]+"/versions/"+term["version_id"]
        headers_obj={"Content-Type":"application/json", "Authorization":"Bearer "+token}
        AttList=[]
        attValueListCSV = []
        for i in range(0,customAttCnt):
           attValueListCSV.append(customAttValueList[i][0])
          
        for i in range(0,customAttCnt):
           print(attValueListCSV)
           print(term["customAtt"][i]["name"])
           attIndex = attValueListCSV.index(term["customAtt"][i]["name"])
            #termAttIDList.append(term["customAtt"][i]["custom_attribute_definition_id"])
           if len(term["customAtt"][i]["values"]) == 0:
              term["customAtt"][i]["values"].append({"value":customAttValueList[attIndex][index]})
           else: 
              term["customAtt"][i]["values"][0]["value"] = customAttValueList[attIndex][index]
           AttList.append(term["customAtt"][i])


        patchdData = json.dumps({"custom_attributes":AttList,"revision": "3"})
        response = requests.patch(url_patch,data=patchdData,headers=headers_obj,verify=False)
        if response.status_code == 200:
           url_getTaskID = data["URL"]+"/v3/workflow_user_tasks?artifact_id="+term["artifact_id"]
           headers_obj={"Accepts": "application/json","Content-Type":"application/json", "Authorization":"Bearer "+token}
           response_getTaskID = requests.get(url_getTaskID, headers=headers_obj,verify=False)
           if response_getTaskID.status_code == 200:
              responseJson=response_getTaskID.json()
              taskId = responseJson["resources"][0]["metadata"]["task_id"]
              actionData = json.dumps({"action": "complete","form_properties": [{"id": "action","value": "#publish"}]})
              url_publish = data["URL"]+"/v3/workflow_user_tasks/"+taskId+"/actions"
              response_publish = requests.post(url_publish,data=actionData,headers=headers_obj,verify=False)
              if response_publish.status_code != 200:
                 print(response_publish.content)
           else:
             print(response_getTaskID.content)
        else:
           print(response.content)


accessToken = GetToken()
termCnt = GetTermsCnt(accessToken)
print("TermCnt = " + str(termCnt) )

updateTermName,customAttValueList = getUpdateValue(updateFile)
offset = 0
while offset < termCnt:
  print("offset = " + str(offset) )
  print("************")
  terms = GetTerms(accessToken,offset)
  patchUpdate(terms,updateTermName,customAttValueList,accessToken)
  offset = offset + 200
