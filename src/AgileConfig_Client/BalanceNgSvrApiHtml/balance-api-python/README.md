# balance-api-python

与 `../BalanceNgSvrApi` 相同的 API：`GET /api/health`、`POST /api/submit`（`multipart/form-data`，字段 `name`、可选 `remark`、可选 `file`）。上传写入本目录 `uploads/`。

- 默认 **`http://127.0.0.1:5091`**
- 改端口（PowerShell）：`$env:PORT='8091'; python main.py`

## 环境要求

- **Python 3.10+**（推荐安装时勾选 *Add to PATH*）
- 能访问 **PyPI**（或已配置 pip 镜像）

## 环境初始化（Windows）

**推荐一键启动**（自动创建 `.venv`、安装依赖、运行 `main.py`）：

```powershell
cd balance-api-python
.\start.ps1
```

**手动**：

```powershell
cd balance-api-python
py -3 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python main.py
```

## 自检

另开终端：

```powershell
curl.exe http://127.0.0.1:5091/api/health
```

应返回含 `"ok":true` 的 JSON。
