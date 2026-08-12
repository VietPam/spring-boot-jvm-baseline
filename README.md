# spring-boot-jvm-baseline

Mình tạo repo này để public thử một baseline Spring Boot khởi động theo kiểu truyền thống — chạy bằng **JVM**. Đây là vế đầu tiên trong một phép so sánh nhỏ mình đang ấp ủ: sau này mình sẽ dựng thêm một repo song song, cùng ứng dụng nhưng build theo hướng **GraalVM native image**, để đặt cạnh nhau xem sự khác biệt thực tế lớn tới đâu khi ca hai thuc hien cold start sau 1 khoang thoi gian inactive.

## Mục tiêu

Cả hai baseline (JVM và GraalVM native, sau này) đều sẽ được host **free** trên [Render](https://render.com) bằng gói Free plan. Mục đích cuối cùng không phải để chạy production gì cả, mà để đo và so sánh: **thời gian cold start sau khi service bị Render cho ngủ vì inactive** — bên JVM khởi động lại chậm cỡ nào so với bên GraalVM native. Đây là câu hỏi thực tế mình tò mò từ lâu, giờ dựng hẳn 2 baseline để tự trả lời bằng số liệu thay vì đoán.

## Pipeline CI/CD

Repo có sẵn 1 pipeline đơn giản chạy trên GitHub Actions: mỗi Pull Request sẽ tự chạy **lint** (kiểm tra format bằng Spotless, phân tích tĩnh bằng SpotBugs) và **test** (unit test). Khi merge vào `master` thì build và push Docker image lên GHCR; khi mình tạo tag release thì pipeline tự gọi Render để deploy bản mới.

Hướng dẫn chi tiết từng job, trigger, cách image được gắn tag: [docs/pipeline.md](docs/pipeline.md)

## Cấu hình Gradle & unit test

Version của mọi dependency/plugin được quản lý tập trung qua Gradle Version Catalog ([gradle/libs.versions.toml](gradle/libs.versions.toml)), kèm sẵn unit test mẫu và cấu hình coverage (Jacoco) để làm nền cho các thay đổi sau này.

## Git Workflow

Mình có ghi lại quy trình git đơn giản đang áp dụng cho repo (nhánh, Pull Request, merge, tạo tag release) để sau này đóng góp thêm cũng theo đúng 1 chuẩn:

[docs/git-workflow.md](docs/git-workflow.md)

## Tech stack

- **Java 25** (Eclipse Temurin)
- **Spring Boot 4.1.0** (Spring Framework 7) — module `spring-boot-starter-webmvc`
- **Gradle** — quản lý version tập trung qua [gradle/libs.versions.toml](gradle/libs.versions.toml) (Version Catalog)
- **Docker** — multi-stage build, runtime chạy user non-root trên `eclipse-temurin:25-jre-alpine`
- **Chất lượng code**: Spotless (format), SpotBugs (static analysis), Jacoco (coverage)
- **CI/CD**: GitHub Actions → GitHub Container Registry (GHCR) → [Render](https://render.com) (free tier)
