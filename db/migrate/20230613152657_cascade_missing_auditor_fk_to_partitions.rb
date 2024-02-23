# frozen_string_literal: true

# Copyright (C) 2023 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

class CascadeMissingAuditorFkToPartitions < CanvasPartman::Migration
  disable_ddl_transaction!
  tag :postdeploy
  self.base_class = Auditors::ActiveRecord::GradeChangeRecord

  def up
    with_each_partition do |partition|
      add_index partition, :grading_period_id, where: "grading_period_id IS NOT NULL", algorithm: :concurrently, if_not_exists: true
    end
  end

  def down
    with_each_partition do |partition|
      remove_index partition, :grading_period_id, algorithm: :concurrently, if_exists: true
    end
  end
end