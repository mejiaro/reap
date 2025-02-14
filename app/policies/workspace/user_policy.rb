module Workspace
  class UserPolicy < WorkspacePolicy
    %i[index create new_modal].each do |action|
      define_method("#{action}?") do
        user.organization_admin? && record.current_organization == user.current_organization
      end
    end

    scope_for :relation do |relation|
      if user.organization_admin?
        relation.joins(:organizations).where(organizations: user.current_organization).distinct
      else
        relation.none
      end
    end
  end
end
