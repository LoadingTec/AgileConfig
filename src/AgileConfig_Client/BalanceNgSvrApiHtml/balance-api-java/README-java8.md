# balance-api-java — 备选：Spring Boot 2.7 + JDK 8

当本机**只有 JDK 8**（或无法安装 JDK 17）时，使用本说明；**推荐**仍优先使用主文档 **`README.md`**（Spring Boot 3 + JDK 17）。

| 项 | 说明 |
|----|------|
| **构建文件** | **`pom-java8.xml`**（Spring Boot **2.7.18**，`java.version` **1.8**） |
| **源码** | 与默认工程共用 **`src/`**；`ApiController` 使用 **Java 8 兼容**写法（无 `String.isBlank` / `InputStream.transferTo`） |
| **端口** | 与默认相同：**5092**（`application.properties`） |

## 启动（Windows）

`start-java8.ps1` 会**自动发现**已安装的 JDK（含未加入 PATH 的目录），必要时通过 **`winget --source winget`** 安装 Temurin 8 或 17（跳过易出证书问题的 **msstore** 源）（JDK 17 也可编译本工程的 Java 8 目标）。仅安装 JDK 可执行 **`.\install-jdk.ps1 8`** 或 **`.\install-jdk.ps1 17`**。

```powershell
cd balance-api-java
.\start-java8.ps1
```

**手动：**

```powershell
mvn -f pom-java8.xml -DskipTests spring-boot:run
```

## 打 JAR

```powershell
mvn -f pom-java8.xml -q -DskipTests package
java -jar .\target\balance-api-java-1.0.0-SNAPSHOT.jar
```

> 若同时存在用 **`pom.xml`** 与 **`pom-java8.xml`** 打出的产物，请 **`mvn clean`** 后再打另一种，避免混用缓存。

## 自检

```powershell
curl.exe http://127.0.0.1:5092/api/health
```
