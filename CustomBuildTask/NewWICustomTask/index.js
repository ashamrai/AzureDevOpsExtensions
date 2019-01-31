"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const tl = require("azure-pipelines-task-lib/task");
var XMLHttpRequest = require("xmlhttprequest").XMLHttpRequest;
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            //get inputs
            const inputWIType = tl.getInput('workitemtype', true);
            const inputTitle = tl.getInput('titletemplate', false);
            const inputAssignedTo = tl.getInput('assignedto', false);
            const inputLinkToBuild = tl.getInput('linktobuild', true);
            //get variables
            const strAC = tl.getVariable('System.AccessToken');
            if (strAC == null) {
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
            function createNewWorkItem(wiFields, wiLinks) {
                const urlCreateTask = '/_apis/wit/workitems/$' + inputWIType + '?api-version=2.0';
                let patchFields = [];
                //add filed values
                function AddPatchForField(value, key, map) {
                    patchFields.push({ "op": "add", "path": "/fields/" + key, "from": "", "value": value });
                }
                //add link values
                function AddPatchForLink(value, key, map) {
                    if (key === strBuildUri)
                        patchFields.push({ "op": "add", "path": "/relations/-", "from": "", "value": { "rel": value, "url": key, "attributes": { "name": "Build" } } });
                    else
                        patchFields.push({ "op": "add", "path": "/relations/-", "from": "", "value": { "rel": value, "url": key } });
                }
                wiFields.forEach(AddPatchForField);
                if (wiLinks.size > 0)
                    wiLinks.forEach(AddPatchForLink);
                //create request to service
                let devRequest = new XMLHttpRequest();
                let encodedData = new Buffer(":" + strAC).toString('base64');
                devRequest.open("POST", strServiceUrl + strTeamProjectName + urlCreateTask);
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
                            console.log('Error', devRequest.responseText);
                    }
                };
            }
            let newFields = new Map();
            let newLinks = new Map();
            let titleEnd = strBuildDefName + ": " + strBuildNumber;
            if (strReleaseWebUrl != null)
                strReleaseDefName + ": " + strReleaseName + " - " + strReleaseStage;
            if (inputTitle != null)
                newFields.set('System.Title', inputTitle + ' ' + titleEnd);
            else
                newFields.set('System.Title', titleEnd);
            if (inputAssignedTo != null)
                newFields.set('System.AssignedTo', inputAssignedTo);
            if (inputLinkToBuild != "No") {
                if (strReleaseWebUrl != null)
                    newLinks.set(strReleaseWebUrl, 'Hyperlink');
                else if (inputLinkToBuild === "LinkAsArtifact")
                    newLinks.set(strBuildUri, 'ArtifactLink');
                else
                    newLinks.set(strServiceUrl + strTeamProjectName + "/_build/index?buildId=" + strBuildId + "&_a=summary", 'Hyperlink');
            }
            createNewWorkItem(newFields, newLinks);
        }
        catch (err) {
            tl.setResult(tl.TaskResult.Failed, err.message);
        }
    });
}
;
run();
