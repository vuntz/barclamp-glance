#
# Cookbook Name:: glance
# Recipe:: ceph
#
# Copyright (c) 2015 SUSE Linux GmbH.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

ceph_conf = node[:glance][:rbd][:store_ceph_conf]
admin_keyring = node[:glance][:rbd][:store_admin_keyring]

ceph_env_filter = " AND ceph_config_environment:ceph-config-default"
ceph_servers = search(:node, "roles:ceph-osd#{ceph_env_filter}") || []
if ceph_servers.length > 0
  include_recipe "ceph::keyring"
else
  # If external Ceph cluster will be used,
  # we need install ceph client packages
  return unless File.exists?(ceph_conf) && File.exists?(admin_keyring)

  if node[:platform] == "suse"
    package "ceph-common"
    package "python-ceph"
  end
end

# If ceph.conf and admin keyring will be available 
# we have to check ceph cluster status
cmd = ["ceph", "-k", admin_keyring, "-c", ceph_conf]
check_ceph = Mixlib::ShellOut.new(cmd)

return unless check_ceph.run_command.stdout.match("(HEALTH_OK|HEALTH_WARN)")

ceph_user = node[:glance][:rbd][:store_user]
ceph_pool = node[:glance][:rbd][:store_pool]

ceph_caps = { 'mon' => 'allow r', 'osd' => "allow class-read object_prefix rbd_children, allow rwx pool=#{ceph_pool}" }

ceph_client ceph_user do
  ceph_conf ceph_conf
  admin_keyring admin_keyring
  caps ceph_caps
  keyname "client.#{ceph_user}"
  filename "/etc/ceph/ceph.client.#{ceph_user}.keyring"
  owner "root"
  group node[:glance][:group]
  mode 0640
end

ceph_pool ceph_pool do
  ceph_conf ceph_conf
  admin_keyring admin_keyring
end
