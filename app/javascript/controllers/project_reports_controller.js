import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="project-reports"
export default class extends Controller {

  connect() {
    this.addEventListeners();
  }

  addEventListeners(){
    const timeframeSelection = document.querySelector('#timeframe-selection');
    const clientSelection = document.querySelector('#client-selection');
    const projectSelection = document.querySelector('#project-selection');

    if(timeframeSelection)
      this.addCustomTimeframeListener(timeframeSelection);

    if(clientSelection)
      this.addClientSelectionListener(clientSelection);

    if(projectSelection)
      this.addProjectSelectionListener(projectSelection);

  }

  addCustomTimeframeListener(timeframeSelection){
    const customTimeframeDiv = document.querySelector('#custom-timeframe-container');

    timeframeSelection.addEventListener('change', (event)=>{
      if(timeframeSelection.value == "custom")
        customTimeframeDiv.classList.remove('hidden');
      else
        customTimeframeDiv.classList.add('hidden');
    });
  }

  addClientSelectionListener(clientSelection){
    const projectSelection = document.querySelector('#project-selection');
    const membersCheckboxes = document.querySelector('#members-checkboxes');
    const tasksCheckboxes = document.querySelector('#tasks-checkboxes');

    clientSelection.addEventListener('change', event=>{
      const clientId = clientSelection.value;
      if (clientId > 0){
        $.ajax({
          type: 'GET',
          url: `/project_reports/update_projects_selection`,
          data: {client_id: clientId},
          success:(data)=>{
            projectSelection.innerHTML = data;
          },
          error:(data)=>{
            console.error(data);
          }
        })       
      }
      else{
        projectSelection.innerHTML = '<option value="0">Select a project</option>';
      }
      membersCheckboxes.innerHTML = null;
      tasksCheckboxes.innerHTML = null;
    });
  }

  addProjectSelectionListener(projectSelection){
    const membersCheckboxes = document.querySelector('#members-checkboxes');
    const tasksCheckboxes = document.querySelector('#tasks-checkboxes');

    const members_url = `/project_reports/update_members_checkboxes`;
    const tasks_url = `/project_reports/update_tasks_checkboxes`;


    projectSelection.addEventListener('change', event=>{
      const projectId = projectSelection.value;
      this.updateCheckboxes(membersCheckboxes, projectId, members_url);
      this.updateCheckboxes(tasksCheckboxes, projectId, tasks_url)
    });
  }

  updateCheckboxes(checkboxes, projectId, checkbox_url){
    if (projectId > 0){
      $.ajax({
        type: 'GET',
        url: checkbox_url,
        data: {project_id: projectId},
        success:(data)=>{
          checkboxes.innerHTML = data;
        },
        error:(data)=>{
          console.error(data);
        }
      })       
    }
    else{
      checkboxes.innerHTML = null;
    }
  }
}
