# GitLab 与仓库远程（HTTP / SSH）配置

## 环境说明

| 项 | 值 |
|----|-----|
| Web 控制台 | `http://192.168.201.139:9080/hgroup/akcc` |
| HTTP 克隆/推送地址 | `http://192.168.201.139:9080/hgroup/akcc.git` |
| SSH（宿主机） | `ssh://git@192.168.201.139:2022/hgroup/akcc.git`（端口 **2022→容器 22**） |
| SSH（容器内主机名示例） | `git@cfb0ac84500c:hgroup/akcc.git`（仅在能解析该主机名时使用） |

GitLab 容器示例（`docker ps` 节选）：

```text
cfb0ac84500c   gitlab/gitlab-ce:latest   ...   0.0.0.0:2022->22/tcp, 0.0.0.0:9080->80/tcp, 0.0.0.0:8443->443/tcp   gitlab
```

将**本地已整合的代码**（含客户端等）推到内网 GitLab 时，可**保留原有 `origin` 地址不变**，再为其它地址单独起远程名，从而支持**向多个远程推送**。

---

## 1. 远程地址：保留原有 + 增加其它远程

**不要改**现有 `origin`（除非你明确要迁移主远程）。先查看当前配置：

```bash
git remote -v
```

为**另一个**推送地址新增具名远程（名称自定，示例用 `gitlab-http`）：

```bash
git remote add gitlab-http http://192.168.201.139:9080/hgroup/akcc.git
git remote -v
```

### 1.1 增加 SSH 远程（推荐，避免 HTTP 被 GCM 拒绝）

在 **Windows** 上使用 **明文 HTTP** 访问 GitLab 时，Git Credential Manager 可能报错：

`fatal: Unencrypted HTTP is not recommended for GitLab...`

处理方式二选一：**改用 HTTPS**（若 GitLab 已开 8443 等），或 **改用 SSH 推送**。本环境 Web 为 `9080`，SSH 映射为 **`192.168.201.139:2022`**，可增加远程名 `gitlab-ssh`：

```bash
git remote add gitlab-ssh ssh://git@192.168.201.139:2022/hgroup/akcc.git
git remote -v
```

若名称已存在：

```bash
git remote set-url gitlab-ssh ssh://git@192.168.201.139:2022/hgroup/akcc.git
```

**首次推送并建立上游**（分支名按实际，如 `dev-deploy`）：

```bash
git push --set-upstream gitlab-ssh dev-deploy
```

需已在 GitLab 账户中配置 **SSH 公钥**，且本机能访问 `192.168.201.139:2022`。首次连接若提示 host key 确认，输入 `yes` 即可。

#### 可选：用 `~/.ssh/config` 写成短地址

```text
Host gitlab-hgroup-akcc
  HostName 192.168.201.139
  Port 2022
  User git
  IdentityFile ~/.ssh/id_ed25519
```

然后：

```bash
git remote add gitlab-ssh git@gitlab-hgroup-akcc:hgroup/akcc.git
```

与 `ssh://git@192.168.201.139:2022/hgroup/akcc.git` 等价，便于换密钥或换 IP。

若该名称已存在，可改为更新 URL：

```bash
git remote set-url gitlab-http http://192.168.201.139:9080/hgroup/akcc.git
```

可继续添加更多远程，例如：

```bash
git remote add backup https://example.com/other/group/repo.git
git remote -v
```

删除不再使用的远程：`git remote remove <名称>`。

---

## 2. 推送到不同远程

同一分支可分别推到 `origin`、`gitlab-http` 等（分支名按实际修改，如 `main` / `dev-deploy`）：

```bash
git add .
git status
git commit -m "chore: sync integrated sources"   # 若已有提交可省略

# 推到原有远程（保持习惯不变）
git push origin main

# 推到 HTTP 内网 GitLab（若本机 GCM 禁止明文 HTTP，请改用下方 SSH）
git push --set-upstream gitlab-http main       # 首次为该远程建立上游
# 之后可简写为：
git push gitlab-http main

# 推到 SSH 内网 GitLab（推荐，见 §1.1）
git push --set-upstream gitlab-ssh main
```

**首次**为某个远程建立跟踪后，也可在对应远程上指定默认上游（按需）：

```bash
git branch --set-upstream-to=gitlab-http/main main
```

日常只更新代码、需要**两个远程都同步**时，执行两次 `git push` 即可；Git 不会自动向所有远程推送。

使用 HTTP 时，GitLab 会提示输入用户名与密码；建议优先使用 **Personal Access Token** 作为密码（账户设置 → Access Tokens）。

### 可选：一次 `git push origin` 推到多个 URL

若 `origin` 的 **fetch** 已指向主仓库（例如 SSH），只希望**再增加一路推送**到 HTTP，可只追加一条 push URL（勿重复添加与 fetch 相同的那条）：

```bash
git remote set-url --add --push origin http://192.168.201.139:9080/hgroup/akcc.git
git remote -v
```

之后 `git push origin main` 会向所有已配置的 push URL 各推一次。行为与 `fetch` URL 的组合因 Git 版本可能略有差异；更直观、更稳妥的做法仍是上文**多个远程名**分别 `git push`。

---

## 参考：首次用 SSH 从容器主机名克隆（可选）

与内网 SSH 配置一致时使用：

```bash
git clone git@cfb0ac84500c:hgroup/akcc.git
cd akcc
git switch --create main
touch README.md
git add README.md
git commit -m "add README"
git push --set-upstream origin main
```

若需在保留 SSH `origin` 的同时增加 HTTP 镜像，按上文 **§1** 使用 `git remote add gitlab-http ...` 即可，无需替换 `origin`。
