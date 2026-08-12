# Pipeline CI/CD

Toàn bộ pipeline định nghĩa trong 1 file duy nhất: [.github/workflows/docker-publish.yml](../.github/workflows/docker-publish.yml). Tài liệu này giải thích trigger nào chạy job nào, và ý nghĩa từng bước — dùng để trace khi pipeline đỏ hoặc khi cần sửa/mở rộng sau này.

## Sơ đồ tổng quan

```
push tag "vX.Y.Z"                    push code vào master              mở PR vào master
        │                                     │                                │
        ▼                                     ▼                                ▼
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                  test        lint                                  │
│                            (chạy song song, độc lập nhau)                          │
└───────────────────────────────────────────────────────────────────────────────────┘
        │                                     │                                │
        ▼                                     ▼                                ✗ (dừng ở đây)
┌───────────────────────────────────────────────────────────────────────────────────┐
│                              build-and-push                                        │
│              build Docker image, push lên GHCR kèm tag phù hợp                     │
└───────────────────────────────────────────────────────────────────────────────────┘
        │                                     │
        ▼                                     ✗ (dừng ở đây, không deploy)
┌───────────────────────────────────────────────────────────────────────────────────┐
│                                   deploy                                           │
│         gọi webhook Render, chỉ chạy khi trigger là tag release (vX.Y.Z)           │
└───────────────────────────────────────────────────────────────────────────────────┘
```

## Trigger (`on:`)

| Sự kiện | `test` / `lint` | `build-and-push` | `deploy` |
|---|---|---|---|
| Mở/update PR vào `master` | ✅ chạy | ❌ skip (`if: github.event_name != 'pull_request'`) | ❌ skip |
| Push code thường vào `master` | ✅ chạy | ✅ chạy | ❌ skip (ref không phải tag) |
| Push git tag `vX.Y.Z` | ✅ chạy | ✅ chạy | ✅ chạy |
| Push nhánh khác (không phải `master`, chưa mở PR) | ❌ không có gì chạy | ❌ | ❌ |
| `workflow_dispatch` (chạy tay từ tab Actions) | ✅ chạy | tuỳ `github.ref` lúc chạy | tuỳ `github.ref` lúc chạy |

> Lưu ý: chỉ push vào 1 nhánh bất kỳ (không phải `master`) mà chưa mở PR thì **không có CI nào chạy cả** — đây là hành vi cố ý, tránh tốn CI cho commit nháp trên nhánh cá nhân.

## Job `test`

Chạy unit test (`./gradlew test`) và xuất báo cáo coverage Jacoco, upload thành artifact `jacoco-report` (giữ 7 ngày) để tải về xem khi cần, kể cả khi job fail (`if: always()`).

## Job `lint`

Chạy song song với `test`, không phụ thuộc nhau. Gồm 2 bước:
- `spotlessCheck` — kiểm tra format code (import order, `googleJavaFormat`). Fail phổ biến nhất nếu quên chạy `./gradlew spotlessApply` trước khi commit.
- `spotbugsMain` + `spotbugsTest` — phân tích tĩnh tìm bug pattern. Cấu hình `ignoreFailures = false`, `reportLevel = medium` trong [build.gradle](../build.gradle) — bất kỳ warning medium trở lên đều fail job.

Upload artifact `static-analysis-reports` (report SpotBugs dạng HTML) kể cả khi fail.

## Job `build-and-push`

Chạy sau khi `test` + `lint` pass (`needs: [test, lint]`). Không chạy trên PR (`if: github.event_name != 'pull_request'`) — image chỉ build/push thật khi code đã ở `master` hoặc khi tạo tag release.

Các bước chính:
1. Tính tên image viết thường (GHCR yêu cầu lowercase).
2. Login GHCR bằng `GITHUB_TOKEN` mặc định (không cần secret riêng).
3. `docker/metadata-action` tính toán các tag sẽ gắn lên image — đây là phần hay gây nhầm lẫn nhất, xem bảng dưới.
4. Build + push bằng `docker/build-push-action`, có cache qua GitHub Actions cache (`type=gha`).

### Cơ chế tag image

| Pattern trong `tags:` | Khi nào có giá trị | Ví dụ |
|---|---|---|
| `type=ref,event=branch` | Trigger là push 1 nhánh | `master` |
| `type=semver,{{version}}` | Trigger là push git tag `vX.Y.Z` | `0.1.0` |
| `type=semver,{{major}}.{{minor}}` | Trigger là push git tag `vX.Y.Z` | `0.1` |
| `type=sha,format=short` | Luôn có | `a1b2c3d` |
| `type=raw,value=latest` (điều kiện `enable`) | **Chỉ khi trigger là git tag** `vX.Y.Z` | `latest` |

**Vì sao `latest` chỉ gắn khi có tag, không gắn mỗi lần merge `master`**: `latest` cần đại diện đúng "bản release mới nhất" — vì job `deploy` (Render) luôn pull image `:latest`. Nếu `latest` nhảy theo mọi lần merge `master` (kể cả code chưa release), Render có thể vô tình chạy code chưa qua release chính thức. Xem thêm [git-workflow.md](git-workflow.md#release--tag).

## Job `deploy`

Chỉ chạy khi trigger là git tag `vX.Y.Z` (`if: startsWith(github.ref, 'refs/tags/v')`), sau khi `build-and-push` xong. Gọi `curl -X POST` tới **Deploy Hook** của Render (lưu ở GitHub Secret `RENDER_DEPLOY_HOOK_URL`) — Render nhận tín hiệu này sẽ tự pull lại image `:latest` và khởi động lại container.

Khai báo `environment: production` để GitHub ghi nhận đây là 1 lần **Deployment** thật, hiển thị trong tab Environments của repo.

### Setup cần thiết (làm 1 lần, ngoài phạm vi repo)

1. Trên Render: tạo Web Service kiểu "Deploy an existing image from a registry", trỏ vào `ghcr.io/<owner>/<repo>:latest`, port `8080`, plan Free.
2. Copy Deploy Hook URL từ Render (Settings → Deploy Hook).
3. Trên GitHub: Settings → Secrets and variables → Actions → thêm secret `RENDER_DEPLOY_HOOK_URL`.

## Việc còn tồn đọng (chưa dọn)

- `push.branches` trong `on:` hiện vẫn còn liệt kê `"ci/setup-github-actions"` (nhánh tạm lúc setup ban đầu, đã xoá) — cần dọn khỏi trigger, chỉ nên còn `"master"`.
