# GitLab CLI helpers

通过 GitLab **REST API v4** 在指定组下创建空项目（无需打开 Web 新建仓库）。默认 API 基址：`https://ako.le1e.com/gitlab/api/v4`。

## 前置条件

1. 在 GitLab 创建 **Personal Access Token**（或具备 `api` 权限的 Project/Group Token）。
2. 你对目标 **组（namespace）** 拥有 **创建项目** 权限。
3. 组路径与浏览器地址栏中的一致（区分大小写以实例为准）。

## 认证

不要将 Token 写入脚本或提交到 Git。使用环境变量：

**Windows (PowerShell)**

```powershell
$env:GITLAB_TOKEN = "<your_token>"
```

**Ubuntu / Linux**

```bash
export GITLAB_TOKEN='<your_token>'
```

可选：自建实例或不同子路径时，Bash 脚本支持覆盖 API 基址：

```bash
export GITLAB_API_BASE='https://your-host/gitlab/api/v4'
```

PowerShell 脚本可通过参数 `-ApiBase` 覆盖（见下文）。

## 用法约定

- **只给一个参数**：视为 **项目名**，组名固定为 **`MaxGp`**。
- **给两个参数**：**组路径**、**项目名**（显示名；仓库 `path` 由脚本规范化为小写连字符）。

## Windows：`gitlab-create-project.ps1`

```powershell
cd <repo>\scripts\gitlab-cli

$env:GITLAB_TOKEN = "<your_token>"

# 在组 MaxGp 下创建项目 “My App”（仓库 path 一般为 my-app）
.\gitlab-create-project.ps1 -Project "My App"

# 指定组
.\gitlab-create-project.ps1 -Group "OtherGp" -Project "My App"

# 位置参数：仅项目名
.\gitlab-create-project.ps1 "My App"

# 位置参数：组名 + 项目名
.\gitlab-create-project.ps1 "OtherGp" "My App"

# 其他 GitLab 实例
.\gitlab-create-project.ps1 -ApiBase "https://example.com/gitlab/api/v4" -Group "g" -Project "p"
```

成功时会打印 `path_with_namespace`、`ssh_url_to_repo`、`http_url_to_repo`。

## Ubuntu / Linux：`gitlab-create-project.sh`

依赖：`curl`、`jq`。

```bash
sudo apt-get update && sudo apt-get install -y curl jq   # Debian/Ubuntu
chmod +x gitlab-create-project.sh
export GITLAB_TOKEN='<your_token>'

# 在组 MaxGp 下创建项目
./gitlab-create-project.sh "My App"

# 指定组 OtherGp
./gitlab-create-project.sh "OtherGp" "My App"
```

## 创建后推送本地仓库

在 GitLab 上项目已存在的前提下：

```bash
git init
git branch -M main
git remote add origin <SSH 或 HTTPS 地址，以脚本输出为准>
git add .
git commit -m "Initial commit"
git push -u origin main
```

## 常见问题


| 现象               | 处理                                     |
| ---------------- | -------------------------------------- |
| 401 / 403        | 检查 Token 是否含 `api` 权限；是否对目标组有建库权限。     |
| 组找不到             | 核对组 **path**（网页 URL 中的路径），与脚本里使用的组名一致。 |
| 409 / path taken | 同组下 `path` 已存在，更换项目名或删除已有项目。           |

---

## 创建用户并授权到项目

`gitlab-create-user-grant.*` 会依次调用：

1. `POST /users` 创建用户（**需要管理员**或具备创建用户权限的 Token）。
2. `POST /projects/:id/members` 将该用户加入指定项目并设置角色（执行 Token 对该项目需有 **Maintainer** 及以上等可管理成员的权限）。

若用户名已存在，脚本会跳过创建，仅尝试添加项目成员。

### 角色 `access_level`

| 名称         | 说明     |
| ------------ | -------- |
| `Guest`      | 访客     |
| `Reporter`   | 报告者   |
| `Developer`  | 开发者（默认） |
| `Maintainer` | 维护者   |

### 初始密码

- 推荐设置环境变量 **`GITLAB_NEW_USER_PASSWORD`**，避免在命令行历史里留下明文密码。
- 若不设置，则使用 GitLab API 的 **`force_random_password`**，需在管理界面或邮件重置后再登录。

### Windows：`gitlab-create-user-grant.ps1`

```powershell
$env:GITLAB_TOKEN = "<admin_or_privileged_token>"
$env:GITLAB_NEW_USER_PASSWORD = "<initial_password>"   # 可选

cd <repo>\scripts\gitlab-cli

# 项目默认解析为 组 MaxGp + 项目 path（与网页 path 一致，如 my-app）
.\gitlab-create-user-grant.ps1 -Email "u@example.com" -Username "dev01" -Name "Dev One" -Project "my-app"

# 指定组与其它角色
.\gitlab-create-user-grant.ps1 -Email "u@example.com" -Username "dev01" -Name "Dev One" -Project "my-app" -Group "OtherGp" -AccessLevel Maintainer

# 仓库不在 MaxGp 下：-Project 传「完整 path with namespace」（含 /），与网页 Settings → General 一致
.\gitlab-create-user-grant.ps1 -Email "u@example.com" -Username "dev01" -Name "Dev One" -Project "SomeGroup/dksys"

# 其它实例
.\gitlab-create-user-grant.ps1 -ApiBase "https://example.com/gitlab/api/v4" -Email ... -Username ... -Name ... -Project ...
```

### Ubuntu / Linux：`gitlab-create-user-grant.sh`

```bash
export GITLAB_TOKEN='<token>'
export GITLAB_NEW_USER_PASSWORD='<initial_password>'   # 可选

chmod +x gitlab-create-user-grant.sh

# 默认组 MaxGp，角色 developer
./gitlab-create-user-grant.sh "u@example.com" "dev01" "Dev One" "my-app"

# 指定组与角色（maintainer / guest / reporter / developer）
./gitlab-create-user-grant.sh "u@example.com" "dev01" "Dev One" "my-app" "OtherGp" "maintainer"

# 完整命名空间（含 /）：第 4 参数为 path_with_namespace；此时不要再传「组」第 5 参数，可选第 5 个为角色
./gitlab-create-user-grant.sh "u@example.com" "dev01" "Dev One" "SomeGroup/dksys" "maintainer"
```

### 示例：创建用户 `maxly`，授权 `dksys` 仓库为开发者

前提：GitLab 上已存在项目；脚本会请求 **`MaxGp/dksys`**（默认组 **`MaxGp`** + 仓库 path **`dksys`**）。

若出现 **`404 Not Found` / Project not found**：多半是 **命名空间不对**（仓库实际不在 `MaxGp` 下）或 **Token 看不到该项目**。请在项目页打开 **Settings → General**，查看 **Project name** 下方的 **path with namespace**，用下面「完整路径」方式重试；并换用对该仓库有 **Maintainer+** 且能调 API 的 Token。

**Windows（PowerShell）— 命令**

```powershell
cd C:\Users\Administrator\source\repos\AgileConfig\scripts\gitlab-cli   # 按你本机仓库路径修改

$env:GITLAB_TOKEN = "<管理员或具备创建用户权限的 Token>"
$env:GITLAB_NEW_USER_PASSWORD = "<首次登录密码>"   # 建议设置；不设则走随机密码

.\gitlab-create-user-grant.ps1 `
  -Email "maxly@le1e.com" `
  -Username "maxly" `
  -Name "maxly" `
  -Project "dksys" `
  -AccessLevel Developer
```

默认已隐含 **`-Group "MaxGp"`**，与「仅项目名 `dksys`」组合即解析为 **`MaxGp/dksys`**。若实际为 **`OtherGroup/dksys`**，请改用：

```powershell
.\gitlab-create-user-grant.ps1 -Email "maxly@le1e.com" -Username "maxly" -Name "maxly" -Project "OtherGroup/dksys" -AccessLevel Developer
```

**Windows — 示例输出（成功，新建用户）**

```text
Created user: maxly (id=127)
Granted on MaxGp/dksys : Developer (member id=89)
```

**Windows — 示例输出（用户已存在，仅补授权）**

```text
User already exists: maxly (id=127); skipping create.
Granted on MaxGp/dksys : Developer (member id=89)
```

（`id` / `member id` 为 GitLab 自动分配，以你实例实际返回为准。）

---

**Ubuntu / Linux（Bash）— 命令**

```bash
cd /path/to/AgileConfig/scripts/gitlab-cli   # 按你本机仓库路径修改

export GITLAB_TOKEN='<管理员或具备创建用户权限的 Token>'
export GITLAB_NEW_USER_PASSWORD='<首次登录密码>'   # 建议设置

chmod +x gitlab-create-user-grant.sh
./gitlab-create-user-grant.sh "maxly@le1e.com" "maxly" "maxly" "dksys"
```

第 5、6 个参数可省略：组默认为 **`MaxGp`**，角色默认为 **`developer`**。等价于显式写：

```bash
./gitlab-create-user-grant.sh "maxly@le1e.com" "maxly" "maxly" "dksys" "MaxGp" "developer"
```

**Ubuntu — 示例输出（成功，新建用户）**

```text
Created user: maxly (id=127)
Note: force_random_password; set password in Admin UI or use GITLAB_NEW_USER_PASSWORD for new users.
Granted on MaxGp/dksys : developer (member id=89)
```

若已设置 **`GITLAB_NEW_USER_PASSWORD`**，则不会出现 `force_random_password` 的提示行。

**Ubuntu — 示例输出（用户已存在，仅补授权）**

```text
User already exists: maxly (id=127); skipping create.
Granted on MaxGp/dksys : developer (member id=89)
```

### 权限与错误

| 现象 | 处理 |
|------|------|
| 403 创建用户 | Token 非管理员或无权 `POST /users`。 |
| 403 添加成员 | Token 对目标项目无「管理成员」权限；或项目路径错误。 |
| 项目不存在 | 确认 `组名/项目path` 与网页 URL 一致（脚本会将项目名规范为小写 slug）。 |
| **404** `Project not found` | 仓库不在默认组 **`MaxGp`** 下：用 **`-Project '实际组/dksys'`** 完整路径；或 Token 对该项目无读权限（GitLab 常返回 404）。 |

---

## 文件说明

| 文件 | 说明 |
|------|------|
| `gitlab-create-project.ps1` | Windows：在组下创建空项目。 |
| `gitlab-create-project.sh` | Linux/macOS：同上。 |
| `gitlab-create-user-grant.ps1` | Windows：创建用户并加入项目成员。 |
| `gitlab-create-user-grant.sh` | Linux/macOS：同上。 |
