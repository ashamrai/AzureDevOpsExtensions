using Microsoft.TeamFoundation.WorkItemTracking.WebApi;
using Microsoft.TeamFoundation.WorkItemTracking.WebApi.Models;
using Microsoft.VisualStudio.Services.Common;
using Microsoft.VisualStudio.Services.WebApi;
using Microsoft.VisualStudio.Services.WebApi.Patch;
using Microsoft.VisualStudio.Services.WebApi.Patch.Json;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace CloneWorkItem
{
    class Program
    {
        static string[] systemFields = { "System.IterationId", "System.ExternalLinkCount", "System.HyperLinkCount", "System.AttachedFileCount", "System.NodeName",
        "System.RevisedDate", "System.ChangedDate", "System.Id", "System.AreaId", "System.AuthorizedAs", "System.State", "System.AuthorizedDate", "System.Watermark",
            "System.Rev", "System.ChangedBy", "System.Reason", "System.WorkItemType", "System.CreatedDate", "System.CreatedBy", "System.History", "System.RelatedLinkCount",
        "System.BoardColumn", "System.BoardColumnDone", "System.BoardLane", "System.CommentCount", "System.TeamProject"}; //system fields to skip

        static string[] customFields = { "Microsoft.VSTS.Common.ActivatedDate", "Microsoft.VSTS.Common.ActivatedBy", "Microsoft.VSTS.Common.ResolvedDate", 
            "Microsoft.VSTS.Common.ResolvedBy", "Microsoft.VSTS.Common.ResolvedReason", "Microsoft.VSTS.Common.ClosedDate", "Microsoft.VSTS.Common.ClosedBy",
        "Microsoft.VSTS.Common.StateChangeDate"}; //unneeded fields to skip

        const string ChildRefStr = "System.LinkTypes.Hierarchy-Forward"; //should be only one parent


        static void Main(string[] args)
        {
            string pat = "<pat>"; //https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate
            string orgUrl = "https://dev.azure.com/<org>";
            string newProjectName = "";
            int wiIdToClone = 0; 


            VssConnection connection = new VssConnection(new Uri(orgUrl), new VssBasicCredential(string.Empty, pat));
            var witClient = connection.GetClient<WorkItemTrackingHttpClient>();

            CloneWorkItem(witClient, wiIdToClone, newProjectName, true);            
        }

        private static void CloneWorkItem(WorkItemTrackingHttpClient witClient, int wiIdToClone, string NewTeamProject = "", bool CopyLink = false)
        {
            WorkItem wiToClone = (CopyLink) ? witClient.GetWorkItemAsync(wiIdToClone, expand: WorkItemExpand.Relations).Result
                : witClient.GetWorkItemAsync(wiIdToClone).Result;

            string teamProjectName = (NewTeamProject != "") ? NewTeamProject : wiToClone.Fields["System.TeamProject"].ToString();
            string wiType = wiToClone.Fields["System.WorkItemType"].ToString();

            JsonPatchDocument patchDocument = new JsonPatchDocument();

            foreach (var key in wiToClone.Fields.Keys) //copy fields
                if (!systemFields.Contains(key) && !customFields.Contains(key))
                    if (NewTeamProject == "" ||
                        (NewTeamProject != "" && key != "System.AreaPath" && key != "System.IterationPath")) //do not copy area and iteration into another project
                        patchDocument.Add(new JsonPatchOperation()
                        {
                            Operation = Operation.Add,
                            Path = "/fields/" + key,
                            Value = wiToClone.Fields[key]
                        });

            if (CopyLink) //copy links
                foreach (var link in wiToClone.Relations)
                {
                    if (link.Rel != ChildRefStr)
                    {
                        patchDocument.Add(new JsonPatchOperation()
                        {
                            Operation = Operation.Add,
                            Path = "/relations/-",
                            Value = new
                            {
                                rel = link.Rel,
                                url = link.Url
                            }
                        });
                    }
                }

            WorkItem clonedWi = witClient.CreateWorkItemAsync(patchDocument, teamProjectName, wiType).Result;

            Console.WriteLine("New work item: " + clonedWi.Id);
        }
    }
}
