import tl = require('azure-pipelines-task-lib/task');
var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;

async function run() {
    try {
        //get inputs
        const inputWIType: string = tl.getInput('woritemtype', true);
        const inputTitle: string = tl.getInput('titletemplate', false);
        const inputAssignedTo: string = tl.getInput('assignedto', false);
        const inputLinkToBuild: string = tl.getInput('linktobuild', true);
        
        //get variables
        const strAC = tl.getVariable('System.AccessToken');   
        
        if (strAC == null)
        {
            tl.setResult(tl.TaskResult.Failed, 'Access to OAuth token is not allowed');
            return;
        }
        
        const strServiceUrl = tl.getVariable('System.TeamFoundationCollectionUri');
        const strTeamProjectName = tl.getVariable('System.TeamProject');
        const strBuildUri = tl.getVariable('Build.BuildURI');        
        const strBuildNumber = tl.getVariable('Build.BuildNumber');        
        const strBuildId = tl.getVariable('Build.BuildId');        
        const strBuildDefName = tl.getVariable('Build.DefinitionName');
        const strReleaseWebUrl = tl.getVariable('Release.ReleaseWebURL');        
        const strReleaseName = tl.getVariable('Release.ReleaseName');        
        const strReleaseDefName = tl.getVariable('Release.DefinitionName');
        const strReleaseStage = tl.getVariable('Release.EnvironmentName');

        //create new work item
        function createNewWorkItem(wiFields: Map<string, string>, wiLinks: Map<string, string>)
        {
            const urlCreateTask = '/_apis/wit/workitems/$' + inputWIType + '?api-version=2.0';

            let patchFields: { "op": string; "path": string; "from": string; "value": any; }[] = [];

            //add filed values
            function AddPatchForField(value: any, key: any, map: any)
            {                
                patchFields.push({"op" : "add", "path": "/fields/" + key, "from": "", "value": value});
            }  

            //add link values
            function AddPatchForLink(value: any, key: any, map: any)
            {                
                if (key === strBuildUri)
                    patchFields.push({"op" : "add", "path": "/relations/-", "from": "", "value": {"rel" : value, "url" : key, "attributes":{"name":"Build"}}});
                else
                    patchFields.push({"op" : "add", "path": "/relations/-", "from": "", "value": {"rel" : value, "url" : key}});
            }                       

            wiFields.forEach(AddPatchForField);
            if (wiLinks.size > 0) wiLinks.forEach(AddPatchForLink);
            
            //create request to service
            let devRequest = new XMLHttpRequest();        
            let encodedData = new Buffer(":" + strAC).toString('base64');
            devRequest.open("POST", strServiceUrl + strTeamProjectName + urlCreateTask)
            devRequest.setRequestHeader('Authorization', 'Basic ' + encodedData);
            devRequest.setRequestHeader('Accept', 'application/json');     
            devRequest.setRequestHeader('Content-Type', 'application/json-patch+json');     
            devRequest.send(JSON.stringify(patchFields));
    
            devRequest.onreadystatechange = function () {
                if (devRequest.readyState === 4) {
                    let newWorkItem = JSON.parse(devRequest.responseText);
                    if ("id" in newWorkItem)
                        console.log("The work item has been created", newWorkItem.id);
                    else
                        console.log('Error',devRequest.responseText);
                }
            }  
        }               

        let newFields = new Map<string, string>(); 
        let newLinks = new Map<string, string>();
        let titleEnd = strBuildDefName + ": " + strBuildNumber;

        if (strReleaseWebUrl != null) strReleaseDefName + ": " + strReleaseName + " - " + strReleaseStage;

        if (inputTitle != null) newFields.set('System.Title', inputTitle + ' ' + titleEnd);
        else newFields.set('System.Title', titleEnd);

        if (inputAssignedTo != null) newFields.set('System.AssignedTo', inputAssignedTo);

        if (inputLinkToBuild != "No")
        {
            if(strReleaseWebUrl != null) 
                newLinks.set(strReleaseWebUrl, 'Hyperlink');         
            else if (inputLinkToBuild === "LinkAsArtifact")
                    newLinks.set(strBuildUri, 'ArtifactLink');         
                else 
                    newLinks.set( strServiceUrl + strTeamProjectName + "/_build/index?buildId=" + strBuildId + "&_a=summary", 'Hyperlink');
        }

        createNewWorkItem(newFields, newLinks);     
    }
    catch (err) {
        tl.setResult(tl.TaskResult.Failed, err.message);
    }
};

run();