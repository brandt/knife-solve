#
# Copyright 2014, Noah Kantrowitz
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/knife'
require 'chef/run_list/run_list_expansion'

class Chef
  class Knife
    class Solve < Knife
      deps do
      end

      banner 'knife solve COOKBOOK...'

      option :node,
        short: '-n',
        long: '--node NAME',
        description: 'Use the run list from a given node'

      option :role,
        short: '-r',
        long: '--role NAME',
        description: 'Use the run list from a given role'

      def run
        environment = config[:environment]
        cookbooks = name_args

        if config[:node]
          node = Chef::Node.load(config[:node])
          environment ||= node.chef_environment
          cookbooks += node.run_list.run_list_items
        elsif config[:role]
          role = Chef::Role.load(config[:role])
          environment ||= role.chef_environment
          cookbooks += role.run_list.run_list_items
        end

        environment ||= '_default'

        cookbooks = cookbooks.map do |arg|
          arg = arg.to_s
          if arg.include?('[')
            run_list = [Chef::RunList::RunListItem.new(arg)]
            expansion = Chef::RunList::RunListExpansionFromAPI.new(environment, run_list, rest)
            expansion.expand
            expansion.recipes
          else
            arg # Just a plain name
          end
        end.flatten.map do |arg|
          # I don't think this is strictly speaking required, but do it anyway
          arg.split('@').first.split('::').first
        end

        ui.info("Solving [#{cookbooks.join(', ')}] in #{environment} environment")

        solve_cookbooks(environment, cookbooks).sort.each do |name, cb|
          print_version(name, cb.version)
        end
      end

      def print_version(name, vers)
        ident = "#{name} #{vers}"
        unless latest?(name, vers)
          ident += ui.color(" (latest: #{latest[name]})", :red)
        end
        msg(ident)
      end

      def latest?(name, vers)
        latest[name] == vers
      end

      def latest
        @latest ||= rest.get_rest("/cookbooks?latest").inject({}) do |collected, c|
          cookbook, versions = c
          collected[cookbook] = versions["versions"].map { |v| v['version'] }.first
          collected
        end
      end

      def solve_cookbooks(environment, cookbooks)
        rest.post_rest("/environments/#{environment}/cookbook_versions", 'run_list' => cookbooks)
      end
    end
  end
end
