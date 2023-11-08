import json
import argparse
import requests
import copy
import re

""""
Modifies panel relating to Ben Job Scheduler.
Adds a Gauge 
query for each Ben Node metric in localhost:8000
"""
parser = argparse.ArgumentParser(description='')
parser.add_argument('--dashboard', type=str)
args = parser.parse_args()

dashbrd = args.dashboard

def trigger_node_util():
    try:
        url = "http://localhost:8001"
        response = requests.get(url)
        response.raise_for_status()  # Raises an exception if the request was not successful (e.g., 4xx or 5xx response)
        print("Triggered URL:", url)
    except requests.exceptions.RequestException as e:
        print("Error while triggering URL:", e)


def fetch_metrics():
    try:
        trigger_node_util() # update node_util metrics
        url = "http://localhost:8000"  # Replace with the correct URL for your Grafana server
        response = requests.get(url)
        response.raise_for_status()  # Raises an exception if the request was not successful (e.g., 4xx or 5xx response)
        return response.text
    except requests.exceptions.RequestException as e:
        print("Error while fetching metrics:", e)
        return None

metrics = fetch_metrics()

with open(dashbrd, "r") as jsonFile:
    dashboard = json.load(jsonFile)

nodes=[]
for line in metrics.split("\n"):
    if line == "" or line.startswith('#') or line.startswith("ben"):
        continue
    match = re.match(r'([^0-9]+)\d*_ben_([^_]+)_', line.split()[0])
    # example: newick01_ben_tronko_size
    # group 1: first word (i.e newick)
    # group 2: word after ben (i.e tronko)
    if match:
        if match.group(1) == match.group(2):
            nodes.append(line.split()[0])
print(nodes)

for panel in dashboard["panels"]:
    try:
        if(panel["title"] == "Ben Server"):
            for panel_ in panel["panels"]:
                if(panel_["title"] == "Node Utilization"):
                    currRefId='A' #fix? shouldnt be able to reach Z. JS2 max of 25 instances
                    query=panel_["targets"][0]
                    newTargets=[]
                    for i in range(0,len(nodes), 2):
                        source='_'.join(nodes[i].split("_")[0:-1])
                        query["expr"]=f"{nodes[i]} / {nodes[i+1]}"
                        query["legendFormat"]=source
                        query["refId"]=currRefId
                        currRefId=chr(ord(currRefId)+1)
                        newTargets.append(copy.deepcopy(query))
                        panel_["targets"]=newTargets
    except:
        continue

with open(dashbrd, "w") as jsonFile:
    json.dump(dashboard, jsonFile)