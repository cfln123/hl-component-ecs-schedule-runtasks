CloudFormation do

    iam_policies = external_parameters.fetch(:scheduler_iam_policies, {})
    IAM_Role(:EventBridgeInvokeRole) do
      AssumeRolePolicyDocument ({
        Statement: [
          {
            Effect: 'Allow',
            Principal: { Service: [ 'events.amazonaws.com' ] },
            Action: [ 'sts:AssumeRole' ]
          }
        ]
      })
      Path '/'
      Policies iam_role_policies(iam_policies)
    end
  
  
    run_tasks.each do |name, task|
      schedule = task['schedule']
      task_name = name.gsub("-","").gsub("_","")
      container_overrides = {}
      container_overrides[:name] = task.has_key?('container') ? task['container'] : "#{task['task_definition']}"
      container_overrides[:command] = task['command'] if task.has_key?('command')
      container_overrides[:environment] = task['env_vars'] if task.has_key?('env_vars')
      container_input = {
        containerOverrides: [container_overrides]
      }

      unless schedule.nil?
        Events_Rule("#{task_name}Schedule") do
          Name FnSub("${EnvironmentName}-#{name}-schedule")
          Description FnSub("${EnvironmentName} #{name} schedule")
          ScheduleExpression schedule
          State Ref(:State)
          Targets [{
            Id: name,
            Arn: Ref(:EcsClusterArn),
            RoleArn: FnGetAtt('EventBridgeInvokeRole', 'Arn'),
            EcsParameters: {
              TaskDefinitionArn: Ref("#{task['task_definition']}"),
              TaskCount: 1,
              LaunchType: 'FARGATE',
              NetworkConfiguration: {
                AwsVpcConfiguration: {
                  Subnets: FnSplit(',', Ref('SubnetIds')),
                  SecurityGroups: [Ref("#{task['task_definition']}SecurityGroup")],
                  AssignPublicIp: "DISABLED"
                }
              }
            },
            Input: FnSub(container_input.to_json())
          }]
        end
      end
    end
  end