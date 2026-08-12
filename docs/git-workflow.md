# Git Workflow

Quy trình chuẩn khi phát triển trên repo này — từ tạo nhánh đến release. Repo có bật **branch protection** trên `master`, nên một số bước dưới đây là bắt buộc, không làm khác được.

## Rule bắt buộc trên `master`

- **Không được push thẳng vào `master`** — mọi thay đổi phải đi qua Pull Request.
- PR **bắt buộc phải có 2 check `test` và `lint` pass** trước khi nút Merge mở khoá (branch protection → Require status checks to pass before merging).
- PR bắt buộc **cập nhật lên `master` mới nhất** trước khi merge (Require branches to be up to date).
- Các rule trên áp dụng **cho cả admin/owner repo** (không cho bypass), để pipeline thật sự là gate bắt buộc chứ không phải hình thức.

> Job `build-and-push` và `deploy` **không** nằm trong danh sách required status check — 2 job này cố tình skip trên PR (chỉ chạy sau khi merge/khi có tag), nên không thể dùng làm điều kiện chặn merge được. Xem lý do ở [pipeline.md](pipeline.md).

## Flow phát triển 1 tính năng/fix

```bash
# 1. Luôn tạo nhánh mới từ master mới nhất
git checkout master
git pull origin master
git checkout -b feature/ten-tinh-nang

# 2. Commit local thoải mái — chưa có CI nào chạy ở bước này
git add <file>
git commit -m "..."

# 3. Push nhánh lên remote — vẫn chưa có CI chạy (trừ khi đã có PR mở)
git push origin feature/ten-tinh-nang
```

**4. Mở Pull Request vào `master`** trên GitHub — lúc này `test` + `lint` mới bắt đầu chạy (event `pull_request`). Mỗi lần push thêm commit vào nhánh đang có PR mở, 2 check này tự chạy lại.

**5. Tự review diff** ở tab "Files changed" trước khi merge — kể cả PR nhỏ.

**6. Merge bằng "Squash and merge"** (không dùng "Merge commit" hay "Rebase and merge"):
- Gộp toàn bộ commit trên nhánh thành **1 commit sạch** trên `master`.
- Trước khi confirm, sửa lại commit message cho rõ ràng (đừng để nguyên danh sách commit thô GitHub tự gợi ý).

**7. Xoá nhánh** ngay sau khi merge (nút "Delete branch" GitHub hiện sẵn), rồi đồng bộ local:
```bash
git checkout master
git pull origin master
git branch -d feature/ten-tinh-nang
git fetch --prune
```

## Release / Tag

Merge vào `master` **không tự động tạo bản release** — image build ra chỉ được gắn tag theo nhánh/sha/`latest`-khi-có-tag (xem [pipeline.md](pipeline.md#cơ-chế-tag-image)). Muốn phát hành 1 bản chính thức (kèm version tag + trigger deploy Render), phải **chủ động tạo git tag**.

### Quy ước version

Theo [Semantic Versioning](https://semver.org): `vMAJOR.MINOR.PATCH`, ví dụ `v0.1.0`. Giai đoạn đầu dùng `0.x.x` (API/behavior còn có thể đổi); khi đủ ổn định mới lên `v1.0.0`.

### Cách 1 — CLI (annotated tag)

```bash
git checkout master
git pull origin master
git tag -a v0.1.0 -m "Release v0.1.0: mô tả ngắn"
git tag -n9              # kiểm tra lại trước khi push
git push origin v0.1.0    # git push thường KHÔNG tự push tag, phải gọi rõ tên tag
```

### Cách 2 — GitHub UI (tạo kèm Release luôn)

Repo → tab **Releases** → **Draft a new release** → ô "Choose a tag" gõ tag mới (`v0.1.0`) → chọn target `master` → điền tiêu đề/mô tả (có thể bấm "Generate release notes" để tự tổng hợp từ các PR đã merge) → **Publish release**.

Cả 2 cách đều tạo ra cùng 1 git tag thật, kích hoạt đúng cùng 1 trigger `push.tags` trong pipeline — không có khác biệt về mặt CI.

### Sau khi push tag

Pipeline tự chạy `test` → `lint` → `build-and-push` (gắn thêm tag `0.1.0`, `0.1`, `latest`) → `deploy` (báo Render pull bản mới). Theo dõi ở tab **Actions**.

**Không xoá/tạo lại tag đã public** — tag là con trỏ cố định, một khi đã push ra ngoài thì nên xem là bất biến.
