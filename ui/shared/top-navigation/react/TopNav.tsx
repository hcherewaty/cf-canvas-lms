/*
 * Copyright (C) 2023 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React from 'react'
import {TopNavBar} from '@instructure/ui-top-nav-bar'
import {Breadcrumb} from '@instructure/ui-breadcrumb'
import useToggleCourseNav from './hooks/useToggleCourseNav'

const TopNav = () => {
  const breadCrumbs = window.ENV.breadcrumbs

  const {toggle} = useToggleCourseNav()

  return (
    <TopNavBar inverseColor={true} width="100%">
      {() => (
        <TopNavBar.Layout
          navLabel="Change this"
          desktopConfig={{
            hideActionsUserSeparator: false,
          }}
          smallViewportConfig={{
            dropdownMenuToggleButtonLabel: 'Toggle Menu',
            dropdownMenuLabel: 'Main Menu',
          }}
          renderBreadcrumb={
            <TopNavBar.Breadcrumb onClick={() => toggle()}>
              <Breadcrumb label="test">
                {breadCrumbs?.map(crumb => (
                  <Breadcrumb.Link key={crumb.name}>{crumb.name}</Breadcrumb.Link>
                ))}
              </Breadcrumb>
            </TopNavBar.Breadcrumb>
          }
        />
      )}
    </TopNavBar>
  )
}

export default TopNav
