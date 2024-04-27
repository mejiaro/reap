class AssignedTask < ApplicationRecord
  include RateConvertible

  self.ignored_columns += [ "name" ]

  belongs_to :project
  belongs_to :task
  has_one :organization, through: :task

  has_many :time_regs, dependent: :destroy

  has_many :users, through: :time_regs

  validates :project_id, uniqueness: { scope: :task_id, message: "is already assigned to the project" }
  validates :rate, numericality: { only_integer: true }

  accepts_nested_attributes_for :task
end
