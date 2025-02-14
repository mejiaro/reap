class MembershipPolicy < ApplicationPolicy
  scope_for :relation, :own do |relation|
    relation.joins(:organization).where(organizations: user.current_organization, user: user).distinct
  end

  scope_for :relation do |relation|
    organization = user.current_organization
    if user.admin?
      relation.joins(:organization).where(organizations: organization).distinct
    else
      relation.joins(:organization).where(organizations: organization, user: user).distinct
    end
  end
end
