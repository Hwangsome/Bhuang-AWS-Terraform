# Terraform Input Variables Datasources Outputs
![img_14.png](..%2Fimg%2Fimg_14.png)
### 三种类型的变量
![img_15.png](..%2Fimg%2Fimg_15.png)

在这个任务中，我们将通过实际演示使用 Terraform 来创建一个 EC2 实例，并动态获取 AWS 的最新 AMI ID，此外还会创建和配置安全组以便能够通过 SSH 和 Web 访问 EC2 实例。
## Step-01: Introduction to variables Section
### 我们要做的主要步骤：
1. 使用 Terraform 的 **输入变量** 进行动态配置。
2. 使用 Terraform 的 **输出值** 来展示我们创建的资源的信息。
3. 使用 Terraform 的 **数据源** 从 AWS 动态获取最新的 AMI ID。
4. 创建 **VPC Web 安全组** 和 **VPC SSH 安全组**，以便能够通过 SSH 和 HTTP 访问 EC2 实例。
5. 将 EC2 实例与现有的 **Key Pair** 关联，方便 SSH 登录。


### 步骤 1: 配置 Terraform 输入变量

Terraform **输入变量** 使得我们可以动态地传递值，而不用硬编码在 Terraform 配置中。我们将定义输入变量以灵活地指定 AWS 区域、实例类型、Key Pair 名称等。

#### `variables.tf`
```hcl
variable "aws_region" {
  description = "The AWS region to launch EC2 instance"
  default     = "us-west-2"
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "key_name" {
  description = "Key Pair name for SSH access"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EC2 instance will be launched"
  type        = string
}
```

### 步骤 2: 使用数据源动态获取最新的 AMI ID

Terraform **数据源** 用于从外部资源（例如 AWS）中获取信息，而不创建新资源。在这里，我们将从 AWS 动态获取最新的 Amazon Linux 2 AMI ID。

#### `main.tf` 中的数据源定义：
```hcl
provider "aws" {
  region = var.aws_region
}

# 动态获取最新的 Amazon Linux 2 AMI ID
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
```

### 步骤 3: 创建 VPC SSH 和 Web 安全组

我们将创建两个安全组：一个用于 SSH 访问（端口 22），另一个用于 Web 访问（端口 80）。虽然可以将它们合并到一个安全组中，但为了演示目的，我们会分开创建，以便展示如何将多个安全组关联到同一个 EC2 实例。

#### `main.tf` 中的安全组定义：
```hcl
# 创建 SSH 安全组
resource "aws_security_group" "ssh_sg" {
  name        = "ssh_security_group"
  description = "Allow SSH access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 创建 Web 安全组
resource "aws_security_group" "web_sg" {
  name        = "web_security_group"
  description = "Allow HTTP access"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

### 步骤 4: 创建 EC2 实例

在创建 EC2 实例时，我们将使用之前通过数据源获取的最新 AMI ID，并将 SSH 和 Web 安全组关联到该实例上。

#### `main.tf` 中的 EC2 实例定义：
```hcl
resource "aws_instance" "ec2_instance" {
  ami           = data.aws_ami.latest_amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name
  security_groups = [
    aws_security_group.ssh_sg.name,
    aws_security_group.web_sg.name
  ]

  tags = {
    Name = "MyTerraformEC2Instance"
  }
}
```

### 步骤 5: 输出值

我们将使用 **输出值**，将 EC2 实例的公共 IP 和实例 ID 作为输出，以便用户在终端可以直接查看这些信息。

#### `outputs.tf`
```hcl
output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.ec2_instance.id
}

output "public_ip" {
  description = "The public IP of the EC2 instance"
  value       = aws_instance.ec2_instance.public_ip
}
```

### Terraform 完整配置文件结构：

1. **`variables.tf`**：定义输入变量。
2. **`main.tf`**：定义 AWS 提供者、数据源、安全组和 EC2 实例。
3. **`outputs.tf`**：定义输出值。

### 最终配置的文件结构：
```bash
.
├── main.tf          # EC2实例和安全组配置
├── outputs.tf       # 输出EC2实例的相关信息
├── variables.tf     # 输入变量定义
```

### 步骤 6: 执行 Terraform 操作

#### 1. 初始化 Terraform
使用 `terraform init` 初始化 Terraform 配置，并下载所需的提供者和模块。

```bash
terraform init
```

#### 2. 规划 Terraform 配置
使用 `terraform plan` 查看 Terraform 将会执行的操作。

```bash
terraform plan
```

#### 3. 应用 Terraform 配置
使用 `terraform apply` 实际创建 EC2 实例和安全组。此命令会执行所有定义的资源操作。

```bash
terraform apply
```

#### 4. 查看输出值
一旦资源创建成功，你将能够看到 `outputs.tf` 中定义的输出值，例如 EC2 实例的 ID 和公共 IP。

### 总结

- 我们通过 **Terraform 数据源** 动态获取了最新的 Amazon Linux 2 AMI ID。
- 创建了两个安全组：一个用于 SSH 访问，一个用于 Web 访问。
- 创建了 EC2 实例，并将这些安全组关联到实例上。
- 使用 **输入变量** 动态配置 AWS 区域、实例类型、Key Pair 名称等信息。
- 使用 **输出值** 展示了 EC2 实例的 ID 和公共 IP。

通过这个配置，你将能够使用 SSH 登录到 EC2 实例，并通过 Web 浏览器访问该实例上运行的 Web 服务器。这展示了 Terraform 在管理 AWS 基础设施时的强大能力，并且演示了如何使用数据源、输入变量、输出值以及安全组来实现复杂的基础设施管理。

## Step-02: c2-variables.tf - Define Input Variables in Terraform

- [Terraform Input Variables](https://www.terraform.io/docs/language/values/variables.html)
- [Terraform Input Variable Usage - 10 different types](https://github.com/stacksimplify/hashicorp-certified-terraform-associate/tree/main/05-Terraform-Variables/05-01-Terraform-Input-Variables)

Terraform 中的 **Input Variables（输入变量）** 是用来提升 Terraform 配置的灵活性和可复用性的重要工具。通过使用输入变量，你可以在运行时动态传递不同的值，而不是在配置文件中硬编码资源属性。这使得 Terraform 模块可以在不同的环境中使用相同的配置，同时只需修改输入变量的值。

### 1. 什么是 Input Variables（输入变量）？

输入变量允许你将可变的配置参数提取到一个独立的地方进行管理，这样你就可以根据不同的场景传递不同的值，而不需要修改基础设施配置代码。输入变量可以传递到模块或顶层配置，来控制资源的属性、行为等。
#### 10 种使用输入变量的方法
![img_16.png](..%2Fimg%2Fimg_16.png)
1. **基本概念**：
   - 输入变量允许 Terraform 模块的参数化，使模块能够在不修改源代码的情况下被不同的配置复用。

2. **在执行时提供**：
   - 当运行 `terraform plan` 或 `terraform apply` 时，如果配置文件中的变量没有默认值，Terraform 会提示用户提供这些变量的值。

3. **使用 CLI 参数覆盖默认值**：
   - 可以在命令行中使用 `-var` 选项直接提供或覆盖变量的值。

4. **使用环境变量覆盖**：
   - 设置环境变量（格式为 `TF_VAR_name`）来覆盖 Terraform 配置中相应变量的默认值。

5. **使用 `terraform.tfvars` 文件提供变量**：
   - 可以创建一个或多个 `terraform.tfvars` 或符合模式 `*.auto.tfvars` 的文件，Terraform 会自动加载这些文件中定义的变量值。

6. **使用任意名称的 `.tfvars` 文件**：
   - 可以通过命令行参数 `-var-file` 指定一个具有任意名称的 `.tfvars` 文件，从而提供变量值。

7. **使用 `auto.tfvars` 文件**：
   - Terraform 自动加载所有名为 `auto.tfvars` 或匹配模式 `*.auto.tfvars` 的文件中的变量。

8. **实现复杂类型结构**：
   - 在输入变量中实现复杂的数据类型，如列表（List）和映射（Map），以支持更灵活和结构化的数据配置。

9. **实施自定义验证规则**：
   - 为输入变量定义自定义的验证规则，确保提供的值符合特定的条件或格式。

10. **保护敏感输入变量**：
   - 为敏感信息如密码、密钥等配置输入变量时，确保这些变量的值不会在日志、CLI输出或其他 Terraform 界面中明文显示。

### 2. 定义输入变量的步骤

Terraform 中的输入变量通过 `variable` 块进行定义，`variable` 块通常包含变量名称、默认值、类型、描述等属性。

#### 变量的基本语法：

```hcl
variable "<VARIABLE_NAME>" {
  type        = <TYPE>        # 变量类型
  default     = <DEFAULT_VALUE> # 默认值（可选）
  description = <DESCRIPTION>  # 变量描述（可选）
}
```

- **`<VARIABLE_NAME>`**：这是变量的名称，用于在配置中引用它。
- **`type`**：指定变量的类型，如 `string`、`number`、`list`、`map` 等。
- **`default`**：设置该变量的默认值。如果没有传递变量值，则使用默认值。
- **`description`**：提供对变量的简短描述，帮助用户了解它的用途。

#### 变量的使用：
定义好变量后，你可以在 Terraform 配置中使用 `var.<VARIABLE_NAME>` 来引用它。

#### 示例：

```hcl
variable "instance_type" {
  type        = string
  default     = "t2.micro"
  description = "The EC2 instance type"
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = var.instance_type  # 使用输入变量
}
```

在这个示例中，`variable "instance_type"` 定义了一个变量，默认值为 `t2.micro`。在 EC2 实例资源中，`instance_type` 通过 `var.instance_type` 被引用，代表 EC2 实例的类型。

### 3. 变量的类型

Terraform 支持多种变量类型，可以使你的配置更加灵活。

#### 常见变量类型：
1. **string（字符串）**：表示一段文本。

   ```hcl
   variable "instance_type" {
     type    = string
     default = "t2.micro"
   }
   ```

2. **number（数字）**：表示一个数值。

   ```hcl
   variable "instance_count" {
     type    = number
     default = 2
   }
   ```

3. **bool（布尔值）**：表示一个布尔类型的值，`true` 或 `false`。

   ```hcl
   variable "enable_logging" {
     type    = bool
     default = true
   }
   ```

4. **list（列表）**：表示一组值的有序列表。

   ```hcl
   variable "availability_zones" {
     type    = list(string)
     default = ["us-east-1a", "us-east-1b"]
   }
   ```

5. **map（映射）**：表示键值对的集合。

   ```hcl
   variable "instance_tags" {
     type    = map(string)
     default = {
       Name = "my-instance"
       Env  = "production"
     }
   }
   ```

6. **object（对象）**：表示一个包含多个键的复杂结构。

   ```hcl
   variable "settings" {
     type = object({
       name    = string
       enabled = bool
       tags    = map(string)
     })
     default = {
       name    = "my-instance"
       enabled = true
       tags    = {
         Name = "example"
       }
     }
   }
   ```

### 4. 输入变量的传递方式

Terraform 提供了多种方式来传递输入变量的值，你可以在运行时传递变量，也可以通过文件、环境变量等方式设置。

#### 4.1 **命令行传递**

你可以通过 `-var` 标志在运行 `terraform plan` 或 `terraform apply` 时传递变量值。

```bash
terraform apply -var="instance_type=t3.medium"
```

#### 4.2 **变量文件传递**

你可以将变量的值存储在一个 `.tfvars` 文件中，然后在运行 Terraform 时引用这个文件。

##### `terraform.tfvars` 文件：

```hcl
instance_type = "t3.medium"
```

在运行时，通过 `-var-file` 传递变量文件：

```bash
terraform apply -var-file="terraform.tfvars"
```

Terraform 也会自动识别名为 `terraform.tfvars` 或 `*.auto.tfvars` 的变量文件，无需显式传递。

#### 4.3 **环境变量**

Terraform 允许使用环境变量来传递输入变量，环境变量的格式是 `TF_VAR_<VARIABLE_NAME>`。例如，传递 `instance_type` 变量的值：

```bash
export TF_VAR_instance_type="t3.medium"
terraform apply
```

### 5. 使用输入变量的好处

1. **提高可复用性**：通过变量，你可以将同样的 Terraform 配置应用于不同的环境，比如开发、测试和生产，只需修改输入变量即可。
2. **易于配置管理**：使用变量，你可以将配置参数从代码中提取出来，便于集中管理和修改。
3. **灵活性**：输入变量允许你动态传递参数，使得 Terraform 配置可以根据不同的需求进行灵活调整。
4. **简化模块化配置**：当你使用模块时，变量是传递模块参数的主要方式，使模块更具通用性。

### 6. 输入变量的高级功能

#### 6.1 **变量验证**

Terraform 允许在变量中添加自定义验证规则，确保传入的变量值符合预期。

```hcl
variable "instance_type" {
  type = string
  default = "t2.micro"

  validation {
    condition = contains(["t2.micro", "t3.micro"], var.instance_type)
    error_message = "Instance type must be t2.micro or t3.micro."
  }
}
```

在这个例子中，只有 `t2.micro` 或 `t3.micro` 被允许作为 `instance_type` 的值，如果传递了其他值，Terraform 会抛出自定义错误信息。

#### 6.2 **复杂结构：对象和元组**

Terraform 的输入变量还支持复杂的数据结构，如对象（object）和元组（tuple），这使得你可以更精细地控制基础设施配置。

##### 示例：对象（object）

```hcl
variable "instance_settings" {
  type = object({
    instance_type = string
    disk_size     = number
    tags          = map(string)
  })
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = var.instance_settings.instance_type
  tags          = var.instance_settings.tags
}
```

##### 示例：元组（tuple）

```hcl
variable "instance_list" {
  type = list(object({
    instance_type = string
    disk_size     = number
  }))
}

resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = var.instance_list[0].instance_type
}
```

### 7. 输入变量与模块结合使用

在 Terraform 模块中，输入变量非常重要，因为它们允许模块的调用者根据需要传递参数，使得模块更加灵活和通用。

#### 模块中的变量：

```hcl
module "my_module" {
  source = "./path/to/module"
  instance_type = "t3.medium"  # 传递变量给模块
}
```

模块内部使用 `variable` 块定义这些变量，并根据传入的值进行资源的创建或修改。

### 8. 总结

Terraform 中的输入变量是一个强大而灵活的工具，可以用来定义动态的基础设施配置。通过输入变量，你可以：
- **提高配置的可复用性**，使得相同的代码可以应用于不同环境。
- **动态控制资源的属性**，而不需要修改核心配置文件。
- **简化模块化管理**，使得复杂的基础设施配置可以通过模块传递参数来进行灵活调整。

无论是简单的配置，还是复杂的模块化架构，输入变量都是 Terraform 管理基础设施时的核心组成部分。

## Step-04: c4-ami-datasource.tf - Define Get Latest AMI ID for Amazon Linux2 OS
- [Data Source: aws_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami)
  **Terraform 的 `data` 块** 是 Terraform 中用于查询和获取外部数据的一个非常重要的功能块，它允许我们从现有的资源或外部系统中动态获取信息，而不创建新的资源。这种查询操作称为 **数据源**，通过 `data` 块，Terraform 可以从云平台或服务中获取数据，而不必重新创建资源。

### 1. `data` 块的作用

`data` 块主要用于以下场景：
- **查询现有资源**：从云提供商中查询已经存在的资源（如现有的 AWS VPC、AMI、S3 存储桶等），而不是重新创建它们。
- **获取动态数据**：获取动态的资源信息，比如查询最新的 AMI ID、当前的 EC2 实例、现有的 DNS 记录等。
- **复用已有资源**：通过 `data` 块，我们可以将现有资源引入 Terraform 管理的上下文中进行复用。
- **查询外部 API**：从外部 API 中获取信息，比如获取最新的 GitHub 仓库信息、Kubernetes 集群中的现有资源等。

### 2. `data` 块的结构
数据资源在 Terraform 中通过 data 块声明。这个 data 块指定了数据资源所要使用的数据源，数据源决定了数据资源将读取的对象类型以及可用的查询参数。
`data` 块的基本语法如下：
```hcl
data "<PROVIDER_NAME>_<RESOURCE_TYPE>" "<NAME>" {
  # 查询资源的过滤条件或其他参数
}
```

- **`<PROVIDER_NAME>`**：提供者的名称，例如 `aws`、`google` 等。
- **`<RESOURCE_TYPE>`**：数据源的类型，例如 `aws_ami`（用于查询 AWS 的 AMI）。
- **`<NAME>`**：这个数据源的名称，供 Terraform 内部使用，可以是任何有效的标识符。

### 3. `data` 块的常见使用场景

#### 1. 查询最新的 AMI ID
这是 `data` 块最常见的使用场景之一。你可以使用 `aws_ami` 数据源来查询 AWS 上的最新 AMI ID，然后将其用于创建 EC2 实例。

#### 示例：查询最新的 Amazon Linux 2 AMI ID
```hcl
data "aws_ami" "latest_amazon_linux" {
  most_recent = true   # 获取最新的 AMI
  owners      = ["amazon"]  # 仅查询由 Amazon 官方发布的 AMI

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]  # 过滤条件，查找符合条件的 AMI
  }
}

resource "aws_instance" "web_server" {
  ami           = data.aws_ami.latest_amazon_linux.id  # 使用查询到的 AMI ID
  instance_type = "t2.micro"
}
```

在这个例子中，`data` 块使用 `aws_ami` 数据源来查询 AWS 中最新的 Amazon Linux 2 AMI，并将该 AMI ID 用于后续的 EC2 实例创建。

#### 2. 查询现有的 AWS VPC
如果你想将新的资源放置到现有的 AWS VPC 中，而不是创建新的 VPC，可以使用 `aws_vpc` 数据源来查询当前 AWS 账户中的 VPC。

#### 示例：查询现有的 VPC
```hcl
data "aws_vpc" "default" {
  default = true  # 查询默认的 VPC
}

resource "aws_subnet" "default_subnet" {
  vpc_id     = data.aws_vpc.default.id  # 使用查询到的 VPC ID
  cidr_block = "10.0.1.0/24"
}
```

在这个例子中，`data` 块查询 AWS 中的默认 VPC，并将其用于创建新的子网。

#### 3. 查询 S3 存储桶
`data` 块也可以用来查询现有的 AWS S3 存储桶，而无需重新创建它们。

#### 示例：查询现有的 S3 存储桶
```hcl
data "aws_s3_bucket" "my_bucket" {
  bucket = "my-existing-bucket"
}

resource "aws_s3_bucket_object" "example" {
  bucket = data.aws_s3_bucket.my_bucket.id  # 使用查询到的 S3 存储桶 ID
  key    = "example.txt"
  source = "example.txt"
}
```

在这个例子中，我们通过 `aws_s3_bucket` 数据源查询现有的 S3 存储桶，并在这个存储桶中上传文件。

#### 4. 查询外部 API 数据（例如 GitHub）
除了云资源，`data` 块还可以用来查询外部 API。例如，使用 `github` 提供者查询 GitHub 仓库信息。

#### 示例：查询 GitHub 仓库信息
```hcl
data "github_repository" "example_repo" {
  name = "hashicorp/terraform"
}

output "repo_description" {
  value = data.github_repository.example_repo.description
}
```

在这个例子中，我们查询了 GitHub 上 `hashicorp/terraform` 仓库的信息，并输出该仓库的描述。

### 4. `data` 块的使用注意事项

1. **只查询，不创建资源**：`data` 块只能用于查询现有的资源或外部数据，它不会创建新的资源。如果你需要创建资源，需要使用 `resource` 块。
2. **依赖关系管理**：`data` 块可以与其他 `resource` 块建立依赖关系。例如，某些数据源可能依赖于现有的资源，Terraform 会在运行时自动解析这些依赖关系。
3. **过滤条件**：许多数据源支持通过过滤条件（`filter`）来查询特定的资源。确保过滤条件精确，以避免查询到不相关的资源。

### 5. `data` 块的完整示例

以下是一个完整的 Terraform 配置示例，它展示了如何使用 `data` 块查询多个资源并创建新的 AWS 资源。

#### 示例：使用数据源查询最新的 AMI 和现有的 VPC
```hcl
# 提供者配置
provider "aws" {
  region = "us-west-2"
}

# 动态获取最新的 Amazon Linux 2 AMI
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# 查询现有的默认 VPC
data "aws_vpc" "default" {
  default = true
}

# 在现有 VPC 中创建一个子网
resource "aws_subnet" "default_subnet" {
  vpc_id     = data.aws_vpc.default.id  # 使用查询到的 VPC ID
  cidr_block = "10.0.1.0/24"
}

# 使用查询到的最新 AMI 创建 EC2 实例
resource "aws_instance" "web_server" {
  ami           = data.aws_ami.latest_amazon_linux.id  # 使用最新的 AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.default_subnet.id  # 将实例部署到现有的子网中

  tags = {
    Name = "MyWebServer"
  }
}

# 输出 EC2 实例的公共 IP
output "instance_public_ip" {
  value = aws_instance.web_server.public_ip
}
```

### 6. 常用的 Terraform 数据源

Terraform 支持大量的 **数据源**，根据不同的云提供商和服务，常见的数据源包括：
- **AWS 数据源**：`aws_ami`、`aws_vpc`、`aws_s3_bucket`、`aws_subnet` 等。
- **Google Cloud 数据源**：`google_compute_instance`、`google_storage_bucket` 等。
- **Azure 数据源**：`azurerm_resource_group`、`azurerm_storage_account` 等。
- **其他数据源**：`github_repository`（GitHub）、`kubernetes_pod`（Kubernetes）等。

### 7. 数据源与资源的区别

- **`resource` 块**：用于创建、更新和删除资源。资源是 Terraform 实际管理的基础设施元素。
- **`data` 块**：用于查询现有资源或外部系统中的数据。它不会创建或修改资源，只是读取和获取数据。

#### 示例对比：
```hcl
# 通过 resource 创建新资源
resource "aws_instance" "web_server" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}

# 通过 data 查询已有资源
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
}
```

- `resource` 块用于创建新的 EC2 实例。
- `data` 块用于查询 AWS 中的现有 AMI。

### 数据资源的用途
- 获取外部定义的数据：数据资源可以查询并获取在当前 Terraform 配置之外定义的数据。例如，它可以用来获取一个由不同 Terraform 配置管理的 AWS VPC 的 ID 或特定的 AMI。
- 与其他配置集成：如果你有多个 Terraform 配置管理不同的基础设施层或组件，数据资源可以帮助这些配置共享数据，无需重复创建资源。
- 减少硬编码：通过查询现有资源而非硬编码资源ID，可以使配置更加灵活和可维护。

#### 示例：使用 AWS VPC 数据资源
假设你需要创建一个 EC2 实例，并需要将其部署到一个已经存在的 VPC 中。你可以使用数据资源来查询这个 VPC 的 ID。
    
```hcl
    data "aws_vpc" "selected" {
   tags = {
      Name = "Production"
   }
}

resource "aws_instance" "my_instance" {
   ami           = "ami-123456"
   instance_type = "t2.micro"
   vpc_id        = data.aws_vpc.selected.id

   tags = {
      Name = "MyInstance"
   }
}

```
在这个例子中，data.aws_vpc.selected 数据资源根据标签名查询名为 "Production" 的 VPC，并将其 ID 用于创建新的 EC2 实例。

#### 依赖性解析和 depends_on
与管理资源相似，数据资源也遵循依赖性解析规则。你可以使用 depends_on 元参数来显式指定数据资源的依赖关系。

使用 depends_on 可以确保在读取数据资源之前，其依赖的资源已经被创建或更新。这在处理资源创建顺序敏感的场景中特别有用。
```hcl
data "aws_instance" "example" {
  instance_id = "i-12345678"
  depends_on = [
    aws_instance.new_instance
  ]
}
```
在此示例中，Terraform 会等待 aws_instance.new_instance 资源创建完成后，再查询 ID 为 i-12345678 的实例的详细信息。

### 总结

- **`data` 块** 是 Terraform 用于从现有资源或外部系统中查询数据的工具，常用于获取动态信息，如最新的 AMI ID、现有的 VPC 或 S3 存储桶等。
- **使用场

景**：当我们需要复用现有资源或查询外部数据时，`data` 块是非常有用的。它不会创建资源，只会查询数据。
- **典型应用**：获取最新的 AMI、查询现有的 AWS 资源（如 VPC、S3 存储桶）、从外部 API 获取数据（如 GitHub 仓库）。

理解 `data` 块的使用可以帮助你在 Terraform 配置中更灵活地处理外部资源和数据查询，优化基础设施代码的编写。

## Step-06: c6-outputs.tf - Define Output Values
- [Output Values](https://www.terraform.io/docs/language/values/outputs.html)


在 Terraform 中，**Output Variables（输出变量）** 是用来输出或展示资源的属性或计算结果的。它们通常用于在 Terraform 完成资源的创建、修改后，将一些重要的结果返回给用户。例如，可以使用输出变量来显示 EC2 实例的 IP 地址、S3 存储桶的名称，或者将这些值传递给其他模块或脚本。

输出变量在 Terraform 中的几个主要用途：
- 在 CLI 输出中显示值：
  - 根模块（root module，即最顶层的 Terraform 配置）可以定义输出值，这些输出值在执行 terraform apply 后会在命令行界面（CLI）中显示。这对于查看关键信息如公网 IP 地址、资源标识符等特别有用。
- 模块间共享资源属性：
  - 子模块（child module，即被根模块调用的模块）可以通过定义输出值来披露其管理的一部分资源属性给父模块（parent module）。这使得父模块能够接收并利用这些数据，进行进一步的资源配置或逻辑判断。
- 通过远程状态访问输出值：
  - 当使用远程状态存储（如 S3、Consul 等）时，根模块的输出值可以被其他 Terraform 配置通过 terraform_remote_state 数据源访问。这种方式允许不同的 Terraform 配置共享和利用相同的基础设施信息，促进了不同项目或团队之间的协作。

### 1. 如何定义 Output Variables（输出变量）

在 Terraform 中，输出变量通过 `output` 块来定义。一个 `output` 块包括名称和 `value` 参数，`value` 是你希望输出的表达式或值。

#### 语法：

```hcl
output "<OUTPUT_NAME>" {
  value = <EXPRESSION>
  description = <DESCRIPTION>   # 可选，描述输出变量
  sensitive = <BOOLEAN>         # 可选，标记输出值是否敏感（例如密码）
}
```

- **`<OUTPUT_NAME>`**：输出变量的名称，用于标识这个输出变量。
- **`value`**：表示要输出的具体值，通常是某个资源的属性值或计算结果。
- **`description`**（可选）：为这个输出变量添加描述，帮助其他用户理解其含义。
- **`sensitive`**（可选）：将其标记为敏感信息（如密码），Terraform 不会在命令行或日志中输出该值。

### 2. Output Variables 的作用

- **向用户展示重要信息**：例如，当你创建一个 EC2 实例后，你可能想输出这个实例的 `public_ip`，这样用户可以知道如何访问该实例。
- **跨模块共享数据**：当你在一个模块中创建资源后，你可以通过输出变量将这些资源的属性传递给另一个模块使用。
- **脚本和自动化工作流中的集成**：例如，你可以通过 Terraform 的输出结果将资源信息传递给其他自动化工具或脚本。

### 3. 定义输出变量的示例

#### 示例 1：输出 EC2 实例的 ID 和 Public IP
- [aws_instance resource attribute](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#attribute-reference)
```hcl
resource "aws_instance" "example" {
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}

# 输出 EC2 实例的 ID
output "instance_id" {
  value       = aws_instance.example.id
  description = "The ID of the EC2 instance"
}

# 输出 EC2 实例的 Public IP
output "instance_public_ip" {
  value       = aws_instance.example.public_ip
  description = "The public IP address of the EC2 instance"
}
```

在这个示例中：
- **`aws_instance.example.id`** 是 EC2 实例的 ID。
- **`aws_instance.example.public_ip`** 是 EC2 实例的公网 IP 地址。
- 通过 `output` 块，我们将这两个属性输出到终端，以便用户可以看到这些关键资源信息。

#### 示例 2：输出多个值

Terraform 的 `output` 块可以输出多个值。例如，可以通过列表或映射输出多个资源的属性。

```hcl
resource "aws_instance" "example" {
  count         = 3
  ami           = "ami-12345678"
  instance_type = "t2.micro"
}

# 输出多个 EC2 实例的 Public IP
output "instances_public_ip" {
  value = aws_instance.example[*].public_ip  # 输出所有实例的 Public IP
}
```

在这个例子中，我们创建了 3 个 EC2 实例，并通过输出变量展示它们的所有 `public_ip`，输出值是一个 IP 地址的列表。

### 4. 输出敏感信息

如果输出变量包含了敏感信息（如密码、API 密钥等），你可以通过设置 `sensitive = true` 来隐藏它们的输出。这可以防止敏感信息被暴露在 Terraform 的命令行输出或日志文件中。

#### 示例：输出敏感信息

```hcl
resource "aws_db_instance" "example" {
  allocated_storage = 20
  engine            = "mysql"
  instance_class    = "db.t2.micro"
  username          = "admin"
  password          = "password123"  # 敏感信息
  db_name           = "exampledb"
}

# 输出数据库的连接地址
output "db_endpoint" {
  value       = aws_db_instance.example.endpoint
  description = "The endpoint of the RDS instance"
}

# 输出数据库密码（敏感信息）
output "db_password" {
  value       = aws_db_instance.example.password
  description = "The password of the RDS instance"
  sensitive   = true  # 将密码标记为敏感信息
}
```

在这个例子中：
- `db_password` 被标记为敏感信息，因此 Terraform 不会在终端中展示它的值。

### 5. 使用输出变量进行跨模块传递

在 Terraform 模块中，输出变量是非常重要的，用于跨模块传递数据。一个模块可以通过输出变量将它创建的资源信息传递给另一个模块或顶层配置。

#### 示例：模块中的输出变量

假设你有一个创建 VPC 的模块，VPC 的 ID 通过输出变量传递给其他模块使用。

##### 模块的输出变量：
```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

# 输出 VPC 的 ID
output "vpc_id" {
  value = aws_vpc.main.id
}
```

##### 在主配置中调用模块：
```hcl
module "vpc" {
  source     = "./modules/vpc"
  cidr_block = "10.0.0.0/16"
}

# 获取模块中输出的 VPC ID
output "vpc_id_from_module" {
  value = module.vpc.vpc_id
}
```

在这个例子中，VPC 模块创建了一个 VPC，并通过 `output "vpc_id"` 输出 VPC 的 ID。主配置通过引用 `module.vpc.vpc_id` 来获取 VPC ID。

### 6. 输出值的使用场景

#### 6.1 显示在 Terraform 控制台

当你运行 `terraform apply` 时，所有定义的输出变量会在命令行中展示。这对于查看关键资源的创建结果非常有用。

```bash
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

instance_id = "i-0e1234567890abcdef"
instance_public_ip = "52.123.45.67"
```

#### 6.2 脚本集成

输出变量可以通过命令行工具 `terraform output` 来获取，它们可以集成到其他脚本或工具中。

```bash
# 获取指定输出变量的值
terraform output instance_public_ip
# 返回示例: 52.123.45.67
```

#### 6.3 作为其他模块的输入

一个模块的输出可以作为另一个模块的输入，帮助你建立更复杂的基础设施架构。

#### 示例：
```hcl
module "vpc" {
  source = "./modules/vpc"
}

module "subnet" {
  source = "./modules/subnet"
  vpc_id = module.vpc.vpc_id  # 使用 VPC 模块的输出值
}
```

### 7. Terraform 输出变量的最佳实践

1. **合理使用描述**：为输出变量添加描述信息，以帮助其他用户了解这个输出变量的意义。
2. **使用敏感标记**：对于涉及到密码、密钥等敏感信息，使用 `sensitive = true` 防止它们被暴露。
3. **模块化输出**：当使用模块时，尽量通过输出变量将模块的重要信息传递给调用者，以便其他模块或配置能使用它们。
4. **避免冗余输出**：只输出必要的值，避免过多或无用的输出信息。

### 8. 总结

Terraform 的输出变量是非常重要的工具，它能够：
- 在 Terraform 运行后输出资源的关键信息。
- 将数据从一个模块传递到另一个模块。
- 将 Terraform 运行结果与其他自动化工具或脚本集成。

通过合理地定义和使用输出变量，你可以更好地管理基础设施资源，并在复杂的场景下提高代码的可复用性和灵活性。