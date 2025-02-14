module Workspace
  class TeamsController < WorkspaceController
    skip_verify_authorized

    def index
      @pagy, @users = pagy authorized_scope(User, type: :relation).all
    end

    def new_modal
      @user = authorized_scope(User, type: :relation).new
      @roles = AccessInfo.allowed_organization_roles
    end

    def create
      begin
        @user = User.find_or_create_by!(email: team_member_params[:email]) do |user|
          user.assign_attributes(team_member_params.except(:role).merge(is_verified: false))
        end

        authorized_scope(AccessInfo, type: :relation).create!(
          user: @user,
          organization: current_user.current_organization,
          role: AccessInfo.roles[team_member_params[:role]]
        )

        render turbo_stream: [
          turbo_flash(type: :success, data: t("notice.user_added_to_the_organization")),
          turbo_stream.append(:organization_users, partial: "workspace/teams/user", locals: { user: @user }),
          turbo_stream.action(:remove_modal, :modal)
        ]
      rescue => e
        @roles = AccessInfo.allowed_organization_roles
        render turbo_stream: turbo_stream.replace(:modal, partial: "workspace/teams/form", locals: { user: @user, roles: @roles })
      end
    end

    def implicit_authorization_target
      User
    end

    private

    def team_member_params
      params.require(:user).permit(:email, :first_name, :last_name, :password, :password_confirmation, :role)
    end
  end
end
