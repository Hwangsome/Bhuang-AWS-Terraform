使用 AWS CLI 操作 **CodeDeploy 部署 ECS** 涉及多个步骤和命令，包括应用程序的创建、部署组的配置、AppSpec 文件的上传，以及启动和监控部署。

---

## **1. 创建 CodeDeploy 应用程序**

### 创建应用程序
```bash
aws deploy create-application \
  --application-name <ApplicationName> \
  --compute-platform ECS
```

- `--application-name`: 您的应用程序名称（例如，`MyECSApplication`）。
- `--compute-platform`: 必须设置为 `ECS`。

### 查看所有应用程序
```bash
aws deploy list-applications
```

---

## **2. 配置部署组**

### 创建部署组
```bash
aws deploy create-deployment-group \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName> \
  --deployment-config-name CodeDeployDefault.ECSAllAtOnce \
  --ecs-services clusterName/serviceName \
  --service-role-arn <IAMRoleARN> \
  --load-balancer-info targetGroupPairInfoList=[
    {
      "targetGroups": [
        {"name": "<TargetGroup1>"},
        {"name": "<TargetGroup2>"}
      ],
      "prodTrafficRoute": {
        "listenerArns": ["<ProductionListenerARN>"]
      },
      "testTrafficRoute": {
        "listenerArns": ["<TestListenerARN>"]
      }
    }
  ]
```

参数说明：
- `--application-name`: 应用程序名称。
- `--deployment-group-name`: 部署组名称。
- `--deployment-config-name`: 部署配置，例如：
    - `CodeDeployDefault.ECSAllAtOnce`（立即切换所有流量）。
    - `CodeDeployDefault.ECSCanary10Percent5Minutes`（10% 流量，5 分钟后再切换其余流量）。
    - `CodeDeployDefault.ECSLinear10PercentEvery1Minute`（每分钟增加 10% 流量）。
- `--ecs-services`: 指定 ECS 集群和服务，格式为 `clusterName/serviceName`。
- `--service-role-arn`: CodeDeploy 服务角色的 ARN。
- `--load-balancer-info`: 配置负载均衡器，包括目标组和监听器。

### 查看部署组
```bash
aws deploy get-deployment-group \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName>
```

### 列出所有部署组
```bash
aws deploy list-deployment-groups \
  --application-name <ApplicationName>
```

---

## **3. 准备修订版本（AppSpec 文件）**

### 上传 AppSpec 文件到 S3
将 AppSpec 文件（如 `appspec.yml`）上传到 S3 存储桶中：

```bash
aws s3 cp appspec.yml s3://<BucketName>/<FilePath>
```

- 记下文件路径，稍后用于指定修订版本。

---

## **4. 创建和启动部署**

### 创建部署
```bash
aws deploy create-deployment \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName> \
  --revision revisionType=S3,bucket=<BucketName>,key=<FilePath> \
  --description "Deploying ECS application"
```

参数说明：
- `--application-name`: 应用程序名称。
- `--deployment-group-name`: 部署组名称。
- `--revision`: 部署修订版本来源，支持：
    - `S3`: 使用 S3 存储桶中存储的 AppSpec 文件。
    - `GitHub`: 使用 GitHub 仓库中的代码。
- `--description`: 可选描述信息。

### 查看部署状态
```bash
aws deploy get-deployment \
  --deployment-id <DeploymentID>
```

- `--deployment-id`: 部署任务的唯一 ID，创建部署时返回。

### 列出所有部署
```bash
aws deploy list-deployments \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName> \
  --include-only-statuses <Created|Queued|InProgress|Succeeded|Failed|Stopped|Ready>
```

---

## **5. 回滚部署**

### 启用自动回滚
在部署组中启用自动回滚功能：
```bash
aws deploy update-deployment-group \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName> \
  --auto-rollback-configuration enabled=true,events=DEPLOYMENT_FAILURE
```

参数说明：
- `--auto-rollback-configuration`: 配置自动回滚。
    - `enabled=true`: 启用回滚。
    - `events=DEPLOYMENT_FAILURE`: 部署失败时自动回滚。

---

## **6. 部署配置（自定义流量切换）**

### 创建自定义部署配置
```bash
aws deploy create-deployment-config \
  --deployment-config-name <DeploymentConfigName> \
  --traffic-routing-config type=<Canary|Linear>,timeBasedCanary={canaryPercentage=10,canaryInterval=5}
```

参数说明：
- `--deployment-config-name`: 自定义部署配置名称。
- `--traffic-routing-config`: 流量切换配置：
    - `type`: `Canary`（金丝雀）或 `Linear`（线性）。
    - `timeBasedCanary`: 金丝雀部署参数：
        - `canaryPercentage`: 第一次流量切换的百分比。
        - `canaryInterval`: 等待时间（分钟）。

---

## **7. 监控和日志**

### 查看部署日志
部署日志可以通过以下方式查看：
1. **目标实例的 CodeDeploy 日志**：
   ```bash
   ssh <EC2Instance> "cat /opt/codedeploy-agent/deployment-root/deployment-logs/codedeploy-agent-deployments.log"
   ```

2. **CloudWatch Logs**：
   部署中记录的日志可以在 CloudWatch 中查看。

---

## **8. 清理资源**

### 删除部署组
```bash
aws deploy delete-deployment-group \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName>
```

### 删除应用程序
```bash
aws deploy delete-application \
  --application-name <ApplicationName>
```

---

## **9. 实用命令**

### 列出所有部署配置
```bash
aws deploy list-deployment-configs
```

### 查看部署配置详情
```bash
aws deploy get-deployment-config \
  --deployment-config-name <DeploymentConfigName>
```

### 查看 CodeDeploy 的操作日志
```bash
aws logs get-log-events \
  --log-group-name <LogGroupName> \
  --log-stream-name <LogStreamName>
```

---


# Troubleshooting
### 错误信息：`Deployment group's ECS service must be configured for a CODE_DEPLOY deployment controller.`

这个错误表明您尝试在 AWS ECS 上通过 CodeDeploy 部署应用程序时，目标 ECS 服务未正确配置 **Deployment Controller** 为 `CODE_DEPLOY`。

AWS ECS 支持以下三种部署控制器：
1. **ECS 部署控制器**：默认控制器，直接更新任务定义。
2. **CodeDeploy 部署控制器**：支持蓝/绿部署。
3. **EXTERNAL 部署控制器**：由外部服务管理。

要使用 CodeDeploy 部署 ECS 服务，您必须将 ECS 服务的 **Deployment Controller** 设置为 `CODE_DEPLOY`。

---

### 解决方法

#### **1. 检查 ECS 服务的 Deployment Controller**
使用 AWS CLI 或控制台检查目标 ECS 服务的 **Deployment Controller**。

- 使用 CLI 查看服务配置：
  ```bash
  aws ecs describe-services \
    --cluster <ClusterName> \
    --services <ServiceName>
  ```

  **输出示例：**
  ```json
  {
    "services": [
      {
        "serviceName": "my-service",
        "deploymentController": {
          "type": "ECS"
        }
      }
    ]
  }
  ```

  如果 `type` 为 `ECS`，则服务未配置为 `CODE_DEPLOY`。

---

#### **2. 配置 Deployment Controller 为 CODE_DEPLOY**
在创建或更新服务时，必须设置 **Deployment Controller** 为 `CODE_DEPLOY`。

##### **（A）使用 AWS CLI 更新 ECS 服务**
要更新现有服务，必须重新创建服务，并设置 `--deployment-controller` 为 `CODE_DEPLOY`。

1. **删除现有服务：**
   ```bash
   aws ecs delete-service \
     --cluster <ClusterName> \
     --service <ServiceName> \
     --force
   ```

2. **重新创建服务并配置 Deployment Controller：**
   ```bash
   aws ecs create-service \
     --cluster <ClusterName> \
     --service-name <ServiceName> \
     --task-definition <TaskDefinition> \
     --desired-count <DesiredCount> \
     --deployment-controller type=CODE_DEPLOY \
     --load-balancers targetGroupArn=<TargetGroupArn>,containerName=<ContainerName>,containerPort=<ContainerPort>
   ```

   参数说明：
    - `--deployment-controller type=CODE_DEPLOY`: 设置部署控制器为 CodeDeploy。
    - `--load-balancers`: 配置与服务相关联的负载均衡器。
    - `--task-definition`: 使用的 ECS 任务定义。

---

##### **（B）使用 AWS 管理控制台更新 ECS 服务**
1. 登录到 AWS 控制台并导航到 **ECS** 服务。
2. 打开目标集群并找到服务。
3. 删除现有服务（需确保已配置 Auto Scaling 或备份）。
4. 创建新服务：
    - **Deployment type**: 选择 `Blue/Green deployment (powered by AWS CodeDeploy)`。
    - 配置相关参数（任务定义、负载均衡器等）。
5. 确保服务与 CodeDeploy 集成。

---

#### **3. 配置 CodeDeploy 部署组**
在将 ECS 服务配置为 `CODE_DEPLOY` 后，确保您的 CodeDeploy 部署组也正确关联该服务。

CLI 示例：
```bash
aws deploy create-deployment-group \
  --application-name <ApplicationName> \
  --deployment-group-name <DeploymentGroupName> \
  --ecs-services <ClusterName>/<ServiceName> \
  --service-role-arn <IAMRoleARN> \
  --load-balancer-info targetGroupPairInfoList=[
    {
      "targetGroups": [
        {"name": "<TargetGroup1>"},
        {"name": "<TargetGroup2>"}
      ],
      "prodTrafficRoute": {
        "listenerArns": ["<ProductionListenerARN>"]
      },
      "testTrafficRoute": {
        "listenerArns": ["<TestListenerARN>"]
      }
    }
  ]
```

---

### 注意事项
- **蓝/绿部署必须使用 Application Load Balancer (ALB)**。NLB 不支持蓝/绿部署的健康检查功能。
- **任务定义更新**：确保任务定义中的 `containerName` 和 `containerPort` 与负载均衡器匹配。
- **自动回滚**：为 CodeDeploy 部署组启用自动回滚，提升可靠性。

