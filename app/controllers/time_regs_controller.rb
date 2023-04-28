class TimeRegsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_membership

  require 'activerecord-import/base'
  require 'csv'
  
  def show 
  end

  def index 
  end

  def new 
    @client = Client.find(params[:client_id])   
    @project = @client.projects.find(params[:project_id])    
    @assigned_tasks = Task.select('name, assigned_tasks.id, project_id, task_id')
    .joins(:assigned_tasks).where("project_id = #{@project.id}")        
    @membership = @project.memberships.find_by(user_id: current_user.id)
    @time_reg = @project.time_regs.new
  end

  def create 
    @client = Client.find(params[:client_id])   
    @project = @client.projects.find(params[:project_id])   
    @time_reg = @project.time_regs.build(time_reg_params)
    @membership = @project.memberships.find_by(user_id: current_user.id)
    
    @assigned_tasks = Task.select('name, assigned_tasks.id, project_id, task_id')
    .joins(:assigned_tasks).where("project_id = #{@project.id}")  

    @time_reg.active = false
    @time_reg.updated = Time.now
    if @time_reg.save
        redirect_to client_project_path(@client, @project)
    else
        render :new, status: :unprocessable_entity
    end   
  end

  def edit
    @client = Client.find(params[:client_id])
    @project = @client.projects.find(params[:project_id])
    @assigned_tasks = Task.select('DISTINCT name, assigned_tasks.id, project_id, task_id')
        .joins(:assigned_tasks).where("project_id = #{@project.id}")    
    @membership = @project.memberships.find_by(user_id: current_user.id)
    @time_reg = @project.time_regs.find(params[:id])
  end

  def update
    @client = Client.find(params[:client_id])
    @project = @client.projects.find(params[:project_id])
    @time_reg = @project.time_regs.find(params[:id])
    @membership = @project.memberships.find_by(user_id: current_user.id)

    if @time_reg.update(time_reg_params)
      redirect_to [@client, @project]
      flash[:notice] = "Time entry has been updated"
    else
      flash[:alert] = "cannot update time entry" 
      render :new, status: :unprocessable_entity
    end
  end

  def destroy 
  @client = Client.find(params[:client_id])
  @project = @client.projects.find(params[:project_id])
  @time_reg = @project.time_regs.find(params[:id])

  if @time_reg.destroy
    redirect_to [@client, @project]
    flash[:notice] = "Time entry has been deleted"
    else
      flash[:alert] = "cannot delete time entry" 
      render :new, status: :unprocessable_entity
    end
  end

  def toggle_active
    @client = Client.find(params[:client_id])
    @project = @client.projects.find(params[:project_id])
    @time_reg = @project.time_regs.find(params[:time_reg_id])

    if @time_reg.active
      new_timestamp = Time.now

      old_time = @time_reg.updated.to_i
      new_time = new_timestamp.to_i

      worked_minutes = (new_time - old_time) / 60

      @time_reg.minutes += worked_minutes
      @time_reg.active = false
    else
      @time_reg.updated = Time.now
      @time_reg.active = true
    end
    
    if @time_reg.save
      redirect_to [@client, @project]
    else
      render :new, status: :unprocessable_entity
    end
  end

  def import
    @client = Client.find(params[:client_id])
    @project = @client.projects.find(params[:project_id])
    imported_time_regs = []

    if params[:file].blank?
      flash[:alert] = "Please select a file to import."
      redirect_to client_project_path(@client, @project) and return
    end

    file = params[:file].read
    begin
      CSV.parse(file, headers: true) do |row|
        time_reg_params = row.to_hash.slice('notes', 'minutes', 'assigned_task_id', 'membership_id')
        time_reg_params['notes'] = row['notes']
        time_reg_params['minutes'] = row['minutes']
        time_reg_params['assigned_task_id'] = row['assigned_task_id']
        time_reg_params['membership_id'] = row['membership_id']
        time_reg_params['date_worked'] = row['date_worked']
        imported_time_reg = @project.time_regs.new(time_reg_params)
        if imported_time_reg.valid?
          imported_time_regs << imported_time_reg
        else
          Rails.logger.debug "Invalid time entry: #{imported_time_reg.errors.full_messages}"
        end
      end

      if imported_time_regs.present?
        TimeReg.import(imported_time_regs)
        flash[:notice] = "Time entries imported successfully."
      else
        flash[:alert] = "No valid time entries found in the file."
      end
      redirect_to client_project_path(@client, @project)
      rescue StandardError => e
        flash[:alert] = "There was an error importing the file: #{e.message}"
        redirect_to client_project_path(@client, @project)
    end
  end


  def export
    @client = Client.find(params[:client_id])
    @project = Project.find(params[:project_id])
    @time_regs = @project.time_regs
    csv_data = CSV.generate(headers: true) do |csv|
      # Add CSV header row
      # csv << ['id', 'user_email', 'task_name', 'minutes','created_at', 'updated_at','assigned_task_id', 'user_id', 'membership_id']
      csv << ['date', 'client', 'project', 'task', 'notes', 'minutes', 'first name', 'last name', 'email']
      # Add CSV data rows for each time_reg
      @time_regs.each do |time_reg|
        membership = Membership.find(time_reg.membership.id)

        date = time_reg.date_worked
        client = @client.name
        project = @project.name
        task = Task.find(time_reg.assigned_task.task_id).name
        notes = time_reg.notes
        minutes = time_reg.minutes
        first_name = User.find(time_reg.membership.user_id).first_name
        last_name = User.find(time_reg.membership.user_id).last_name
        email = User.find(time_reg.membership.user_id).email

        csv << [date, client, project, task, notes, minutes, first_name, last_name, email]
      end
    end
    send_data csv_data, filename: "#{Time.now.to_i}_time_regs_for_#{@project.name}.csv"
  end

  private
  def time_reg_params
    params.require(:time_reg).permit(:notes, :minutes, :assigned_task_id, :membership_id, :date_worked)
  end

  def ensure_membership
    client = Client.find(params[:client_id])
    project = client.projects.find(params[:project_id])

    if !project.memberships.exists?(user_id: current_user)
      flash[:alert] = "Access denied"
      redirect_to root_path
    end
  end
end
