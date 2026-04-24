# balance-api-node

Express 实现与 `BalanceNgSvrApi` 相同的 `GET /api/health`、`POST /api/submit`（`multipart/form-data`：`name`、`remark`、`file`）。上传保存在本目录 `uploads/`。

- 默认 **`http://127.0.0.1:5094`**
- 改端口：`$env:PORT='8094'; npm start`

## 环境要求

- **Node.js 18+**（推荐 LTS，[nodejs.org](https://nodejs.org/)），安装后 `node -v`、`npm -v` 正常。

## 环境初始化（Windows）— 仅 API

**一键**（若缺少 `node_modules` 会先 `npm install`）：

```powershell
cd balance-api-node
.\start.ps1
```

**手动**：

```powershell
cd balance-api-node
npm install
npm start
```

## Vue 3 前端（`web/`）

与 API **分两个终端**：先启动本目录 API（5094），再启动 Vite。

**一键（开发）**：

```powershell
cd balance-api-node\web
.\start-dev.ps1
```

**手动**：

```powershell
cd balance-api-node\web
npm install
npm run dev
```

浏览器打开终端里提示的本地地址；`/api` 由 Vite 代理到 `http://127.0.0.1:5094`。

## 生产构建（给 Nginx 静态 root）

```powershell
cd balance-api-node\web
npm install
npm run build
```

产物在 `web/dist/`。Nginx `location /api/` 仍反代到本 Node 进程即可。

## 自检（API）

```powershell
curl.exe http://127.0.0.1:5094/api/health
```
