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

namespace UpdateParentState
{
    class Program
    {
        const string mChildLinkName = "System.LinkTypes.Hierarchy-Forward";
        const string mQueryGetWorkItems = "SELECT [System.Id] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = '{0}'  AND  [Source].[System.WorkItemType] = '{1}'  AND  [Source].[System.State] = '{3}') And ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = '{2}'  AND  [Target].[System.State] = '{4}') ORDER BY [System.Id] mode(MustContain)";
        const string mQueryGetChildsByState = "SELECT[System.Id] FROM WorkItemLinks WHERE([Source].[System.TeamProject] = '{0}'  AND[Source].[System.Id] = {1}) And([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And([Target].[System.WorkItemType] = '{2}'  AND[Target].[System.State] = '{3}') ORDER BY[System.Id] mode(MustContain)";
        const string mQueryGetAllChilds = "SELECT [System.Id] FROM WorkItemLinks WHERE ([Source].[System.TeamProject] = '{0}'  AND  [Source].[System.Id] = {1}) And ([System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward') And ([Target].[System.WorkItemType] = '{2}') ORDER BY [System.Id] mode(MustContain)";
        const string StateFieldName = "System.State";
        const string ServiceUrl = "https://dev.azure.com/{organization}/";
        const string PAT = "your_pat"; //https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate?view=azure-devops
        static WorkItemTrackingHttpClient WITClient;

        static void Main(string[] args)
        {
            try
            {
                List<string> _projects = new List<string>();

                _projects.Add("TFSAgile");

                ConnectToService();

                UpdateForOneChild("User Story", "Task", _projects, "New", "Active", "Active"); //Move a user story to active state if any of child tasks is active
                UpdateForOneChild("Feature", "User Story", _projects, "New", "Active", "Active"); //Move a feature to active state if any of child stories is active
                UpdateForAllChilds("User Story", "Task", _projects, "Active", "Closed", "Closed"); // Close a user story if all tasks were closed
            }
            catch(Exception ex)
            {
                Console.WriteLine("Exception:\n" + ex.Message);
                if (ex.InnerException != null) Console.WriteLine("Inner Exception:\n" + ex.InnerException.Message);
                Console.WriteLine("Stack Trace:\n" + ex.StackTrace);
            }
        }


        /// <summary>
        /// Move the work item to destination state if any of child work items in some state
        /// </summary>
        /// <param name="pParentWIT"></param>
        /// <param name="pChildWIT"></param>
        /// <param name="pTeamProjects"></param>
        /// <param name="pSourceState"></param>
        /// <param name="pDestinationState"></param>
        /// <param name="pChildDetinationState"></param>
        static void UpdateForOneChild(string pParentWIT, string pChildWIT, List<string> pTeamProjects, string pSourceState, string pDestinationState, string pChildDetinationState)
        {
            foreach (string _teamProject in pTeamProjects)
            {
                List<int> _parents = GetParentIdsFromQueryResult(String.Format(mQueryGetWorkItems, _teamProject, pParentWIT, pChildWIT, pSourceState, pChildDetinationState));

                foreach (int _parentId in _parents) UpdateWorkItemState( _parentId, pDestinationState);
            }
        }

        /// <summary>
        /// Move the work item to destination state if all child work items in some state
        /// </summary>
        /// <param name="pParentWIT"></param>
        /// <param name="pChildWIT"></param>
        /// <param name="pTeamProjects"></param>
        /// <param name="pSourceState"></param>
        /// <param name="pDestinationState"></param>
        /// <param name="pChildDetinationState"></param>
        static void UpdateForAllChilds(string pParentWIT, string pChildWIT, List<string> pTeamProjects, string pSourceState, string pDestinationState, string pChildDetinationState)
        {
            foreach (string _teamProject in pTeamProjects)
            {
                List<int> _parents = GetParentIdsFromQueryResult(String.Format(mQueryGetWorkItems, _teamProject, pParentWIT, pChildWIT, pSourceState, pChildDetinationState));                

                foreach (int _parentId in _parents)
                {
                    int _childsWithState = GetChildsCountFromQueryResult(String.Format(mQueryGetChildsByState, _teamProject, _parentId, pChildWIT, pChildDetinationState));
                    int _childsAll = GetChildsCountFromQueryResult(String.Format(mQueryGetAllChilds, _teamProject, _parentId, pChildWIT));

                    if (_childsWithState > 0 && _childsAll > 0 && _childsWithState == _childsAll)
                        UpdateWorkItemState(_parentId, pDestinationState);
                }
            }
        }

        /// <summary>
        /// Get the list of parent ids from the query result
        /// </summary>
        /// <param name="pWiql"></param>
        /// <returns></returns>
        static List<int> GetParentIdsFromQueryResult(string pWiql)
        {
            Wiql _wiql = new Wiql { Query = pWiql };

            WorkItemQueryResult result = WITClient.QueryByWiqlAsync(_wiql).Result;

            if (result.WorkItemRelations != null)
                return (from links in result.WorkItemRelations where links.Source == null select links.Target.Id).ToList();

            return new List<int>();
        }

        /// <summary>
        /// Get the count of childs from the query result
        /// </summary>
        /// <param name="pWiql"></param>
        /// <returns></returns>
        static int GetChildsCountFromQueryResult(string pWiql)
        {
            Wiql _wiql = new Wiql { Query = pWiql };

            WorkItemQueryResult result = WITClient.QueryByWiqlAsync(_wiql).Result;

            if (result.WorkItemRelations != null)
                return (from links in result.WorkItemRelations where links.Source != null select links.Target.Id).Count();

            return 0;
        }

        /// <summary>
        /// Move the work item to the destination state
        /// </summary>
        /// <param name="parentId"></param>
        /// <param name="pDestinationState"></param>
        private static void UpdateWorkItemState(int parentId, string pDestinationState)
        {
            JsonPatchDocument patchDocument = new JsonPatchDocument();

            patchDocument.Add(new JsonPatchOperation()
            {
                Operation = Operation.Add,
                Path = "/fields/" + StateFieldName,
                Value = pDestinationState
            });

            WorkItem _updatedWi = WITClient.UpdateWorkItemAsync(patchDocument, parentId).Result;

            Console.WriteLine("Work Item Has Been Updated:{0} - {1}", _updatedWi.Id, _updatedWi.Fields["System.State"].ToString());
        }

        /// <summary>
        /// Connect to the service
        /// </summary>
        static void ConnectToService()
        {
            VssConnection _connection = new VssConnection(new Uri(ServiceUrl), new VssBasicCredential(string.Empty, PAT));

            WITClient = _connection.GetClient<WorkItemTrackingHttpClient>();
        }
    }
}
