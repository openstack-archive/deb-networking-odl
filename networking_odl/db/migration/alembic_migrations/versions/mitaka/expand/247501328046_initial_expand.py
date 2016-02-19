#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.
#

"""Start of odl expand branch

Revision ID: 247501328046
Revises: b89a299e19f9
Create Date: 2015-09-03 22:27:49.292238

"""

from neutron.db.migration import cli


# revision identifiers, used by Alembic.
revision = '247501328046'
down_revision = 'b89a299e19f9'
branch_labels = (cli.EXPAND_BRANCH,)


def upgrade():
    pass
