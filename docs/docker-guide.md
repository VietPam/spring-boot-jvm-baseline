# Hướng dẫn Docker (local)

Hướng dẫn các lệnh Docker cơ bản để build và chạy ứng dụng `spring-boot-jvm-baseline` ngay tại máy local.

## Yêu cầu

- Đã cài Docker Desktop (Mac/Windows) hoặc Docker Engine (Linux) và đang chạy.
- Chạy các lệnh dưới đây từ thư mục gốc dự án (nơi chứa `Dockerfile`).

## 1. Build image

```bash
docker build -t spring-boot-jvm-baseline:local .
```

- `-t spring-boot-jvm-baseline:local`: đặt tên (tag) cho image.
- `.`: build context là thư mục hiện tại.

Build lại từ đầu, không dùng cache (khi nghi ngờ cache cũ gây lỗi):

```bash
docker build --no-cache -t spring-boot-jvm-baseline:local .
```

## 2. Chạy container

Chạy ở chế độ foreground (thấy log trực tiếp, `Ctrl+C` để dừng):

```bash
docker run --rm -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
```

Chạy nền (detached):

```bash
docker run -d -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
```

- `-p 8080:8080`: map port `8080` của host sang port `8080` trong container.
- `--name jvm-baseline`: đặt tên container để dễ thao tác các lệnh sau.
- `--rm`: tự xoá container khi dừng (dùng khi chạy foreground/test nhanh).
- `-d`: chạy nền (detached mode).

## 3. Kiểm tra ứng dụng

```bash
curl http://localhost:8080/
```

Kết quả mong đợi: `hello from Vietpq`

Hoặc mở trình duyệt: `http://localhost:8080`

## 4. Xem log container

```bash
docker logs -f jvm-baseline
```

- `-f`: theo dõi log liên tục (follow).

## 5. Xem danh sách container / image

Container đang chạy:

```bash
docker ps
```

Tất cả container (cả đã dừng):

```bash
docker ps -a
```

Danh sách image:

```bash
docker images
```

## 6. Dừng / xoá container

Dừng container:

```bash
docker stop jvm-baseline
```

Khởi động lại container đã dừng (không tạo mới):

```bash
docker start jvm-baseline
```

Xoá container (phải dừng trước hoặc dùng `-f`):

```bash
docker rm jvm-baseline
docker rm -f jvm-baseline
```

## 7. Xoá image

```bash
docker rmi spring-boot-jvm-baseline:local
```

## 8. Truy cập shell bên trong container (debug)

```bash
docker exec -it jvm-baseline sh
```

> Lưu ý: image runtime dùng base `alpine`, chỉ có `sh`, không có `bash`.

## 9. Dọn dẹp nhanh (khi cần build lại sạch)

Xoá container đã dừng, image không dùng, cache build:

```bash
docker system prune -f
```

> Cẩn thận: lệnh này xoá dữ liệu Docker không sử dụng trên toàn máy, không chỉ riêng project này.

## Tóm tắt quy trình thường dùng

```bash
docker build -t spring-boot-jvm-baseline:local .
docker run -d -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
curl http://localhost:8080/
docker logs -f jvm-baseline
docker stop jvm-baseline
docker rm jvm-baseline
```
