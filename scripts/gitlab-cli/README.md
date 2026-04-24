# GitLab CLI helpers

通过 GitLab **REST API v4** 在指定组下创建空项目（无需打开 Web 新建仓库）。默认 API 基址：`https://ako.le1e.com/gitlab/api/v4`。

## 前置条件

1. 在 GitLab 创建 **Personal Access Token**（或具备 `api` 权限的 Project/Group Token）。
2. 你对目标 **组（namespace）** 拥有 **创建项目** 权限。
3. 组路径与浏览器地址栏中的一致（区分大小写以实例为准）。

## 认证

不要将 Token 写入脚本或提交到 Git。使用环境变量：(最新的全部权限：glpat-bM_TMKG4hDY_slzyp6aMdW86MQp1OjEH.01.0w08dlwrv）有效期一年：2026年4月24日 20:05:21+1years.

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

- **只给一个参数**：视为 **项目名**，组名固定为 `**MaxGp`**。
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


## 文件说明


| 文件                          | 说明                                                      |
| --------------------------- | ------------------------------------------------------- |
| `gitlab-create-project.ps1` | Windows PowerShell，读 `GITLAB_TOKEN`。                    |
| `gitlab-create-project.sh`  | Linux/macOS Bash，读 `GITLAB_TOKEN`，可选 `GITLAB_API_BASE`。 |


