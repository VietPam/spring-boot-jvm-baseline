# spring-boot-jvm-baseline

Baseline Spring Boot (JVM) tối giản, đóng gói Docker multi-stage, kèm pipeline CI/CD tự động test, lint, publish image lên GHCR và deploy khi có release.

## Tech stack

- **Java 25** (Eclipse Temurin)
- **Spring Boot 4.1.0** (Spring Framework 7) — module `spring-boot-starter-webmvc`
- **Gradle** — quản lý version tập trung qua [gradle/libs.versions.toml](gradle/libs.versions.toml) (Version Catalog)
- **Docker** — multi-stage build, runtime chạy user non-root trên `eclipse-temurin:25-jre-alpine`
- **Chất lượng code**: Spotless (format), SpotBugs (static analysis), Jacoco (coverage)
- **CI/CD**: GitHub Actions → GitHub Container Registry (GHCR) → [Render](https://render.com) (free tier)

## Chạy thử local (không cần Docker)

Yêu cầu: JDK 25 đã cài, `JAVA_HOME` trỏ đúng.

```bash
./gradlew bootRun
```

Kiểm tra:

```bash
curl http://localhost:8080/
```

Kết quả mong đợi: `hello from Vietpq`

## Chạy bằng Docker

Xem hướng dẫn chi tiết, kèm bước verify từng thao tác: [docs/docker-guide.md](docs/docker-guide.md)

## CI/CD Pipeline

Repo dùng 1 workflow duy nhất ([.github/workflows/docker-publish.yml](.github/workflows/docker-publish.yml)) gồm 4 job: `test` → `lint` → `build-and-push` → `deploy`, tự động chạy khi mở PR, merge vào `master`, hoặc tạo tag release.

Giải thích chi tiết từng job, trigger, và ý nghĩa các tag image: [docs/pipeline.md](docs/pipeline.md)

## Git Workflow / Quy tắc đóng góp

Repo bắt buộc đi qua Pull Request, có branch protection yêu cầu `test` + `lint` pass trước khi merge vào `master`. Release được đánh dấu bằng git tag `vX.Y.Z`.

Chi tiết quy trình chuẩn từ tạo nhánh đến release: [docs/git-workflow.md](docs/git-workflow.md)

## Cấu trúc thư mục

```
.
├── src/                                  # Source code chính (com.vietpq.baseline)
├── build.gradle, settings.gradle         # Cấu hình Gradle
├── gradle/libs.versions.toml             # Version Catalog — nguồn version tập trung
├── Dockerfile                            # Multi-stage build
├── .github/workflows/docker-publish.yml  # CI/CD pipeline
└── docs/                                 # Tài liệu chi tiết (docker, pipeline, git workflow)
```
