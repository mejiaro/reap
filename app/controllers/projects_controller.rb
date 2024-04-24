class ProjectsController < ApplicationController
  before_action :authenticate_user!
  verify_authorized except: %i[ import ]

  def show
    @project = Project.find(params[:id])
    authorize! @project
    @tasks = authorized_scope(Task, type: :relation).all
    @assigned_tasks = authorized_scope(AssignedTask, type: :relation).select("tasks.name, assigned_tasks.id, assigned_tasks.project_id, assigned_tasks.task_id")
                                  .joins(:task)
                                  .where(project_id: @project.id)
  end

  def new
    @clients = authorized_scope(Client, type: :relation).all
    @project = authorized_scope(Project, type: :relation).new(client: @clients.first)
    authorize! @project
  end

  def create
    @project = authorized_scope(Project, type: :relation).new(project_params.except(:task_ids))

    # adds each task to the project
    project_params[:task_ids].each do |task_id|
      next if task_id.empty?
      task = Task.find(task_id)
      @project.tasks << task
    end

    authorize! @project

    # tries to save the project in the db
    if @project.save
      # makes the creater of the project a member
      @project.users << current_user
      redirect_to @project
    else
      @clients = authorized_scope(Client, type: :relation).all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @is_in_update = true
    @project = Project.find(params[:id])
    authorize! @project

    @clients = authorized_scope(Client, type: :relation).all

    @assigned_tasks = authorized_scope(AssignedTask, type: :relation).select("tasks.name, assigned_tasks.id, assigned_tasks.project_id, assigned_tasks.task_id")
                                  .joins(:task)
                                  .where(project_id: @project.id)

    @assigned_task = @project.assigned_tasks.new
    @tasks = authorized_scope(Task, type: :relation).all.where.not(id: @project.assigned_tasks.select(:task_id)).select(:id, :name) # no tasks that is already a part om the project
    @new_task = authorized_scope(Task, type: :relation).new
  end

  def update
    @project = Project.find(params[:id])
    authorize! @project

    if @project.update(project_params)
      flash[:notice] = t('notice.project_has_been_updated')
      redirect_to @project
    else
      @tasks = authorized_scope(Task, type: :relation).all
      @clients = authorized_scope(Client, type: :relation).all
      @project = Project.find(delete_params[:id])
      authorize! @project
      @assigned_task = @project.assigned_tasks.new
      @assigned_tasks = authorized_scope(AssignedTask, type: :relation).select("tasks.name, assigned_tasks.id, assigned_tasks.project_id, assigned_tasks.task_id")
                                    .joins(:task)
                                    .where(project_id: @project.id)

      flash[:alert] = t('alert.cannot_update_project')
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tasks = authorized_scope(Task, type: :relation).all
    @clients = authorized_scope(Client, type: :relation).all
    @project = Project.find(delete_params[:id])
    authorize! @project
    @assigned_task = @project.assigned_tasks.new

    # checks the confirmation field before trying to delete
    if delete_params[:confirmation] == "DELETE"
      if @project.destroy
        flash[:notice] = t('notice.project_deleted')
        redirect_to clients_path
      else
        @assigned_tasks = authorized_scope(AssignedTask, type: :relation).select("tasks.name, assigned_tasks.id, assigned_tasks.project_id, assigned_tasks.task_id")
                                      .joins(:task)
                                      .where(project_id: @project.id)

        flash[:alert] = t('alert.could_not_delete_project')
        render :edit, status: :unprocessable_entity
      end
    else
      @assigned_tasks = authorized_scope(AssignedTask, type: :relation).select("tasks.name, assigned_tasks.id, assigned_tasks.project_id, assigned_tasks.task_id")
                                    .joins(:task)
                                    .where(project_id: @project.id)
      flash[:alert] = t('alert.invalid_confirmation')
      render :edit, status: :unprocessable_entity
    end
  end

  def import
    # valid_entries tracks how many entries were successfully imported. imported_time_regs is an empty array for all the time regs.
    imported_time_regs = []
    valid_entries = 0

    # if file is empty or missing
    if params[:file].blank?
      flash[:alert] = t('alert.please_select_a_file_to_import')
      redirect_to clients_path and return
    end

    file = params[:file].read
    begin
      CSV.parse(file, headers: true) do |row|
        time_reg_params = row.to_hash.slice("date", "client", "project", "task", "notes", "minutes", "first name", "last name", "email")

        # "Renames" date column to date_worked, which is the name used in the database.
        time_reg_params["date_worked"] = row["date"]
        time_reg_params.delete("date")

        # Deletes redundant 'client' column and checks if the client exists
        client = row["client"]
        check_client client
        time_reg_params.delete("client")

        # Deletes redundant 'project' column and checks if the project exists
        project = row["project"]
        check_project project
        time_reg_params.delete("project")

        # Deletes redundant 'task' column and checks if the task exists
        task = row["task"]
        check_task task
        time_reg_params.delete("task")

        # Deletes redundant 'assigned_task' column and checks if the task exists
        check_assigned_task task_id: @task.id
        time_reg_params["assigned_task_id"] = @assigned_task.id

        # Deletes redunant name columns
        time_reg_params.delete("first name")
        time_reg_params.delete("last name")

        # Checks if the e-mail and user is valid, and deletes redundant e-mail column
        email = row["email"]
        @user = User.find_by(email: email)
        @membership = authorized_scope(Membership, type: :relation).find_or_create_by(user_id: @user.id, project_id: @project.id)
        time_reg_params.delete("email")
        time_reg_params["membership_id"] = @membership.id

        # Checks if the time entries are valid and adds them to the array if they are
        # Also adds 1 to the valid_entries variable
        imported_time_reg = @project.time_regs.new(time_reg_params)
        imported_time_reg.updated = Time.now
        imported_time_reg.active = false

        if imported_time_reg.valid?
          imported_time_regs << imported_time_reg
          valid_entries = valid_entries + 1
        else
          Rails.logger.debug "Invalid time entry: #{imported_time_reg.errors.full_messages}"
        end
      end

      # If any valid time entries have been added, import them
      if imported_time_regs.present?
        authorized_scope(TimeReg, type: :relation).import(imported_time_regs)
        flash[:notice] = "#{valid_entries} #{t('notice.time_entries_imported_successfully')}"
      else
        flash[:alert] = t('alert.no_time_entries_found_in_the_file')
      end
    rescue StandardError => e # If the e-mail is invalid, flash and error and redirect
        flash[:alert] = t('alert.douple_check_email')
    end
    redirect_to clients_path
  end

  private

  def project_params
    params
      .require(:project)
      .permit(:client_id, :name, :description, :billable_project, :billable_rate_nok, task_ids: [])
  end

  def string_to_float(str)
    str.gsub(",", ".").to_f
  end

  def delete_params
    params.permit(:confirmation, :id)
  end

  # Checks to see if the client already exists, and creates it if it doesn't
  def check_client(client)
    if !authorized_scope(Client, type: :relation).exists?(name: client)
      client_params = { "name" => client, "description" => "Description." }
      @client = authorized_scope(Client, type: :relation).new(client_params)
      @client.save
    else
      @client = Client.find_by(name: client)
    end
  end

  # Checks to see if the project already exists, and creates it if it doesn't
  def check_project(project)
    if !@client.projects.exists?(name: project)
      project_params = { "client_id" => @client.id, "name" => project, "description" => "Description." }
      @project = @client.projects.new(project_params)
      @project.save
    else
      @project = @client.projects.find_by(name: project)
      authorize! @project
    end
  end

  # Checks to see if the task already exists, and creates it if it doesn't
  def check_task(task)
    if !authorized_scope(Task, type: :relation).exists?(name: task)
      @task = authorized_scope(Task, type: :relation).new(name: task)
      @task.save
    else
      @task = Task.find_by(name: task)
    end
  end

  # Checks to see if the assigned task already exists, and creates it if it doesn't
  def check_assigned_task(task_id)
    if !@project.assigned_tasks.exists?(task_id)
      @assigned_task = @project.assigned_tasks.build("task_id" => @task.id)
      @assigned_task.save
    else
      @assigned_task = @project.assigned_tasks.find_by(task_id: @task.id)
    end
  end
end
