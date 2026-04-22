# GitLab 与仓库远程（HTTP）配置

## 环境说明

| 项 | 值 |
|----|-----|
| Web 控制台 | `http://192.168.201.139:9080/hgroup/akcc` |
| HTTP 克隆/推送地址 | `http://192.168.201.139:9080/hgroup/akcc.git` |
| SSH（容器内主机名示例） | `git@cfb0ac84500c:hgroup/akcc.git`，宿主机映射端口 **2022→22** |

GitLab 容器示例（`docker ps` 节选）：

```text
cfb0ac84500c   gitlab/gitlab-ce:latest   ...   0.0.0.0:2022->22/tcp, 0.0.0.0:9080->80/tcp, 0.0.0.0:8443->443/tcp   gitlab
```

将**本地已整合的代码**（含客户端等）统一提交到 HTTP 远程：`http://192.168.201.139:9080/hgroup/akcc.git`。

---

## 1. 设置远程地址

在**已有本地仓库**目录下执行（按实际情况二选一）。

**已有 `origin`：改为 HTTP 地址**

```bash
git remote set-url origin http://192.168.201.139:9080/hgroup/akcc.git
git remote -v
```

**尚无远程：添加 `origin`**

```bash
git remote add origin http://192.168.201.139:9080/hgroup/akcc.git
git remote -v
```

---

## 2. 推送到远程地址

首次推送当前分支并建立上游（示例分支为 `main`，请按实际分支名替换）：

```bash
git add .
git status
git commit -m "chore: sync integrated sources"   # 若已有提交可省略
git push --set-upstream origin main
```

若默认分支已是 `main` 且仅需再次推送：

```bash
git push origin main
```

使用 HTTP 时，GitLab 会提示输入用户名与密码；建议优先使用 **Personal Access Token** 作为密码（账户设置 → Access Tokens）。

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

若后续改为统一走 HTTP，在仓库内执行上文 **§1** 的 `git remote set-url` 即可。
