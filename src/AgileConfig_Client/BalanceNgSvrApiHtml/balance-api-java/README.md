# balance-api-java（默认：Spring Boot 3 + JDK 17）

与 `BalanceNgSvrApi`（C#）相同的 HTTP 契约：`GET /api/health`、`POST /api/submit`（`multipart/form-data`：`name`、可选 `remark`、可选 `file`）。文件保存在 `uploads/`。

| 项 | 说明 |
|----|------|
| **默认构建** | 根目录 **`pom.xml`**：Spring Boot **3.2.x**，**JDK 17+**（字节码 17） |
| **默认端口** | **`http://127.0.0.1:5092`**（`application.properties` 的 `server.port`，环境变量 **`PORT`** 可覆盖） |
| **仅 JDK 8 环境** | 见同目录 **`README-java8.md`**，使用 **`pom-java8.xml`** + **`start-java8.ps1`**（Spring Boot 2.7） |

**JDK 未进 PATH / 本机未装 JDK 时**：`start.ps1` 会依次尝试：从 **`JAVA_HOME`**、`Program Files\Eclipse Adoptium`、`Program Files\Microsoft\jdk*`、`Program Files\Java` 等目录**自动发现**带 `javac` 的 JDK 并临时加入当前进程的 `PATH`；若仍没有，会尝试 **`winget install --source winget EclipseAdoptium.Temurin.17.JDK`**（仅用 **winget** 源，避免 **msstore** 证书错误 `0x8a15005e`；可能需要管理员同意）。也可手动执行 **`.\install-jdk.ps1 17`** 仅安装 JDK，装完后**新开终端**再运行 `start.ps1`。

> **PowerShell 脚本**（`start.ps1` / `start-java8.ps1` / `_ensure-jdk.ps1`）为兼容 Windows 默认编码，**脚本内提示语为英文**；业务 JSON 中的中文文案不变。

## 环境要求（默认路径）

| 组件 | 说明 |
|------|------|
| **JDK** | **17+**，且须含 **`javac`**（完整 JDK） |
| **Maven** | 3.6+；首次构建需能访问 Maven Central（或已配置镜像） |

## 启动（Windows）

```powershell
cd balance-api-java
.\start.ps1
```

`start.ps1` 会在检测到 Java 主版本**未满 17**时提示改用 **`.\start-java8.ps1`**。

**手动：**

```powershell
mvn -DskipTests spring-boot:run
```

## 打 JAR

```powershell
mvn -q -DskipTests package
java -jar .\target\balance-api-java-1.0.0-SNAPSHOT.jar
```

## 自检

```powershell
curl.exe http://127.0.0.1:5092/api/health
```
