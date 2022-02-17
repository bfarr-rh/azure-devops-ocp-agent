# azure-devops-ocp-agent
A self hosted agent in OpenShift for Azure Devops, follow the instructions below to get started

# Pre-requisites

## AzureDevOps
These steps will help get the parameters needed to apply to the Deployment Template provided.

1. Setup a project in Azure Devops and get the URL for the organisation ($AZP_URL) . For example https://dev.azure.com/Organisation_Name
2. Generate and use a PAT to connect an agent with Azure Pipelines  ($AZP_TOKEN)
https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops&tabs=preview-page
3. Setup the Agent Pool ($AZP_POOL)
https://docs.microsoft.com/en-us/azure/devops/pipelines/agents/pools-queues?view=azure-devops&tabs=yaml%2Cbrowser

## OpenShift
These steps will create a project and service account with permissions to run the agent. The project will be the namespace in which the azure agent will run.
Import the templates via an administrator login

1. Import the build agent template into the openshift project. This will make an icon and selectable template from the developer view.
```` 
oc create -f https://raw.githubusercontent.com/bfarr-rh/azure-devops-ocp-agent/master/openshift/azagent-bc-template.yaml -n openshift
```` 
2. Import the deployment template for the agent
```` 
oc create -f https://raw.githubusercontent.com/bfarr-rh/azure-devops-ocp-agent/master/openshift/azagent-deployment.yaml -n openshift
```` 
3. Create an OpenShift project where the agent will run.

4. Build the Azure Agent via the template (azagent-bc-template.yaml). The following parameters may need to be adjusted OPENSHIFT_VERSION, AZP_AGENT_VERSION depending on the openshift version and the azure agent version you want to use. The openshift version determines the oc client version that will be installed. The Azure Agent Version can be adjusted, release details can be found here https://github.com/microsoft/azure-pipelines-agent/releases. 

```` 
- description: OpenShift client binary version to install
  name: OPENSHIFT_VERSION
  value: "4.9.7"
- description: Azure agent install version
  name: AZP_AGENT_VERSION
  value: "2.187.2"
```` 

# Deploying & Running the agent
This is the final step and will require the parameters $AZP_URL, $AZP_TOKEN, $AZP_POOL as a minimum to deploy the agent and connect to your organisation in AzureDevOps.

1. Launch the Deployment Template using parameters as required from what you setup in Pre-requisites
2. The Agent should connect to Azure Project and be ready to accept Jobs
3. Grant permissions to the service agent 
```` 
oc policy add-role-to-user edit system:serviceaccount:<project_name>:azure-agent-sa
```` 
4. You will probably need to add registry view or editor access to the service account as well
```` 
oc policy add-role-to-user registry-editor system:serviceaccount:<project_name>:azure-agent-sa
```` 
5. When developing an azure pipeline, rather than using the default pool setup use within the pipeline
For example where the pool name is OpenShift-Agent, your pipeline yaml file will start with something like below.
```` 
trigger:
- master

pool:
  name: 'OpenShift-Agent'
```` 
  
4. The agent has the oc tool installed running with permissions granted to the service account, use oc commands to interact with the build process. 
Sample pipeline can be found here
https://github.com/bfarr-rh/dot-net-examples/blob/master/azure-pipelines.yml

5. As a default the agent will checkout the code so this will be already present in the agent container
6. The Agent is set to complete with each job and will be restarted by OpenShift
  
## Scaling Agents
The agent can be scaled using the Deployment, this is not fully tested , but each agent will register with its pod name as a suffix to ensure AzureDevops can register with a unique name.

## Updating the Agent
Note the "Update all agents" button will not work with this containerised version of the agent. Simply build a new base agent as per the prerequisite steps.
