在 AWS CLI 中，与 Amazon ECS 集群相关的 API 主要集中在 `aws ecs` 命令中。以下是一些常见的用于管理 ECS 集群的 CLI 命令及其说明。

### 1. 创建集群
创建一个新的 ECS 集群。

```bash
aws ecs create-cluster --cluster-name <ClusterName> [--settings name=value] [--tags key=value] [--capacity-providers name1 name2 ...]
```

示例：

```bash
aws ecs create-cluster --cluster-name my-cluster
```

### 2. 删除集群
删除指定的 ECS 集群。

```bash
aws ecs delete-cluster --cluster <ClusterName>
```

示例：

```bash
aws ecs delete-cluster --cluster my-cluster
```

### 3. 列出集群
列出当前账户下所有的 ECS 集群。

```bash
aws ecs list-clusters
```

### 4. 查看集群详情
获取指定 ECS 集群的详细信息。

```bash
aws ecs describe-clusters --clusters <ClusterName1> <ClusterName2> ...
```

示例：

```bash
aws ecs describe-clusters --clusters my-cluster
```

### 5. 更新集群配置
更新集群的设置，例如容器实例配置或容量提供者。

```bash
aws ecs update-cluster --cluster <ClusterName> [--settings name=value] [--configuration executionRoleArn=<roleArn>,logging=<loggingType>] [--service-connect-defaults namespace=<namespace>]
```

示例：

```bash
aws ecs update-cluster --cluster my-cluster --service-connect-defaults namespace=my-namespace
```

### 6. 列出集群中的任务
列出指定集群中运行的所有任务。

```bash
aws ecs list-tasks --cluster <ClusterName>
```

### 7. 列出集群中的服务
列出指定集群中运行的所有服务。

```bash
aws ecs list-services --cluster <ClusterName>
```

### 8. 列出集群的容器实例
列出集群中所有注册的容器实例。

```bash
aws ecs list-container-instances --cluster <ClusterName>
```

### 9. 获取容器实例的详细信息
获取集群中一个或多个容器实例的详细信息。

```bash
aws ecs describe-container-instances --cluster <ClusterName> --container-instances <InstanceID1> <InstanceID2> ...
```

### 10. 启动任务
在指定的集群上启动任务。

```bash
aws ecs run-task --cluster <ClusterName> --task-definition <TaskDefinition>
```

示例：

```bash
aws ecs run-task --cluster my-cluster --task-definition my-task
```

### 11. 停止任务
停止指定集群上的某个任务。

```bash
aws ecs stop-task --cluster <ClusterName> --task <TaskID>
```

示例：

```bash
aws ecs stop-task --cluster my-cluster --task 1234567890abcdef
```

### 12. 更新 ECS 集群的容量提供者
配置 ECS 集群的容量提供者，设置如何自动扩展 EC2 实例或 Fargate 任务。

```bash
aws ecs put-cluster-capacity-providers --cluster <ClusterName> --capacity-providers <Provider1> <Provider2> ... --default-capacity-provider-strategy capacityProvider=<ProviderName>,weight=<Weight>,base=<Base>
```

示例：

```bash
aws ecs put-cluster-capacity-providers --cluster my-cluster --capacity-providers FARGATE FARGATE_SPOT --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1,base=0
```

### 13. 启用 Execute Command
启用 `execute_command_configuration` 来允许在集群的容器中运行命令。

```bash
aws ecs update-cluster --cluster <ClusterName> --configuration executeCommandConfiguration={logging=DEFAULT}
```

### 14. 列出集群的容量提供者
列出 ECS 集群中配置的所有容量提供者。

```bash
aws ecs describe-clusters --clusters <ClusterName> --query "clusters[*].capacityProviders"
```

### 常见选项说明
- `--cluster-name`：指定集群名称。
- `--task-definition`：指定任务定义名称。
- `--capacity-providers`：指定容量提供者，如 Fargate、EC2 或自定义的容量提供者。
- `--settings`：配置集群的其他设置，例如容器实例日志配置等。

这些命令涵盖了 ECS 集群的基本操作，包括创建、更新、列出和管理集群及其资源。您可以根据实际需求组合使用这些 CLI 命令来管理 ECS 集群。