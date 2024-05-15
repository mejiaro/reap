require "test_helper"

class TimeRegTest < ActiveSupport::TestCase
  def setup
    @time_reg = time_regs(:time_reg_1)
  end

  test "#report scoped data" do
    clients = [ clients(:e_corp) ].map(&:id)
    projects = [ projects(:project_1) ].map(&:id)
    users = [ users(:joe) ].map(&:id)
    tasks = [ tasks(:debug) ].map(&:id)

    regs = TimeReg.for_report(clients, projects, users, tasks)

    assert_equal 2, regs.count
    assert_includes regs, time_regs(:time_reg_1)
    assert_includes regs, time_regs(:time_reg_5)
  end

  test "#current_minutes" do
    assert_equal 120, @time_reg.current_minutes

    @time_reg.update(start_time: 20.minutes.ago)
    assert_equal 140, @time_reg.current_minutes
  end
end
