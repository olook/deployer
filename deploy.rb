#!/usr/bin/env ruby

# -*- encoding : utf-8 -*-
require 'rubygems'
require 'bundler/setup'
require 'aws-sdk'
require 'logger'
require 'optparse'
require 'pp'
require 'yaml'

STACK_ID = 'bd823759-5412-4edf-8fef-0a7e89bb7052'

AWS.config(:logger => Logger.new($stdout), :log_formatter => AWS::Core::LogFormatter.colored)
USER_ACCESS = YAML::load("aws.yml")

class Formater

  def self.colorize status
    if status == 'online'
      color="\e[32m"
    else
      color="\e[31m"
    end

    "#{color}#{status}\e[0m"
  end

end


class Deployer
  
  attr_reader :instances


  def initialize(attributes={})
    @client = AWS::OpsWorks::Client.new({
      config: AWS.config,
      access_key_id: attributes['aws_access_key_id'],
      secret_access_key: attributes['aws_secret_access_key']}
    )
    @instances = {}
    get_servers_data
  end

  def online_instances
    instances.select{|key, values| values[:status] == 'online'}
  end

  def get_deploy_status deploy_id
    deployment = @client.describe_deployments({deployment_ids: [deploy_id]}).data[:deployments].first
    deployment[:status]
  end

  def get_servers_data
    instances = @client.describe_instances({stack_id: STACK_ID})
    instances.data[:instances].each do |instance|
      @instances[instance[:instance_id]] = {
          hostname: instance[:hostname], 
          status: instance[:status],
          dns: instance[:public_dns] }
    end
  end

  def show_instances
    instances.each do |instance_id, values|
      info "#{values[:hostname]} - #{Formater.colorize(values[:status])}"
    end
  end

  def deploy
    info "\e[34m" + "Iniciando o deploy" + "\e[0m"

    size = (online_instances.size + 1) / 2
    instances = online_instances.each_slice(size).to_a

    [0,1].each {|index| deploy_and_wait instances[index]}

    notify_newrelic(USER_ACCESS['aws_user'])

    info "\e[34m" + "Deploy concluido com sucesso" + "\e[0m"
  end

  private 
    def deploy_and_wait instances
      info "Executando deploy em #{instances.map{|id, values| values[:hostname]}}"
      deployment_id = deploy_on(instances.map{|id, values| id})

      exit = false
      while !exit do
        sleep(60)
        status = get_deploy_status(deployment_id)
        exit = (status == 'successful')
      end

      info "Deploy concluido"      
    end

    def deploy_on instance_ids
      @client.create_deployment({
       stack_id: STACK_ID,
       app_id: 'a1f3d439-da1d-4494-a90b-254081461120',
       instance_ids: instance_ids,
       command: {name: 'deploy', args: {}}
      }).data[:deployment_id]
    end

    def notify_newrelic(user)
      revision = `git ls-remote git@github.com:olook/olook.git master`.split("\t").first
      `curl -H "x-api-key:dbf7f72258b9cf5007eb859349cfd968104d69257fe4bb6" -d "deployment[user]=#{user}" -d "deployment[application_id]=476808" -d "deployment[revision]=#{revision}" https://api.newrelic.com/deployments.xml`
    end

    def info text
      AWS.config.logger.info text
    end

end


# client.stop_instance({instance_id: '3b3243fb-b315-4b47-a367-9ebd2648bcc1'})

# puts client.describe_deployments({deployment_ids: ['24a52d34-d17d-49a8-9f6d-f31facd41c2a']})
# puts client.describe_deployments({stack_id: STACK_ID})

 # d_id = client.create_deployment({
 #   stack_id: STACK_ID,
 #   app_id: 'a1f3d439-da1d-4494-a90b-254081461120',
 #   instance_ids: ['ad8a6336-67bf-404f-81b5-1c7c9e17aec1','59a3bf6d-351a-4546-b23f-aebe4305ae22','bb82bd7b-7faa-4645-baaa-e21f1aae586e'],
 #   command: {name: 'deploy', args: {}}
 #   })

# puts d_id

# :command=>{:name=>"deploy", :args=>{"migrate"=>["true"]}}

# deploy_id = deploy_on online_instances.first(2)

# puts client.describe_deployments({deployment_ids: [deploy_id]})

require 'gli'
include GLI::App
 
program_desc 'Amazon OpsWorks Deployer'
 
# flag [:t,:tasklist], :default_value => File.join(ENV['HOME'],'.todolist')
 
pre do |global_options,command,options,args|
  config = YAML.load_file("aws.yml")
  $deployer = Deployer.new(config)
end
 
desc "Exibe os servidores"
command :show do |c|
  c.action do |global_options,options,args|
    $deployer.show_instances
  end
end 

desc "Executa o deploy em todos os servidores que estao online"
command :run do |c|
  c.action do |global_options,options,args|
    $deployer.deploy
  end
end
 
exit run(ARGV)

# d.send(options[:command])




# d.send "notify_newrelic"

# # puts d.online_instances
# size = d.online_instances.size / 2
# # puts size
# instances = d.online_instances.each_slice(size).to_a


# puts "Executando deploy em #{instances.first}"
# d_id = d.deploy_on instances.first
# puts "deploy_id=#{d_id}"

# exit = false
# while !exit do
#   sleep(60)
#   status = d.get_deploy_status d_id
#   exit = (status == 'successful')
# end

# puts "Deploy na primeira metade finalizado"
# d_id = d.deploy_on instances.last


# puts instances.last
