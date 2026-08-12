# Hướng dẫn Docker (local)

Hướng dẫn các lệnh Docker cơ bản để build và chạy ứng dụng `spring-boot-jvm-baseline` ngay tại máy local, kèm cách verify sau mỗi bước.

> **Phạm vi:** tài liệu này mô tả chi tiết cho môi trường **Linux** (dùng Docker Engine + `systemd`). Với macOS/Windows (Docker Desktop) các lệnh `docker` bên dưới tương tự, nhưng bước verify Docker daemon (mục "Yêu cầu") sẽ khác vì Docker Desktop không dùng `systemctl`.

## Yêu cầu

- Đã cài Docker Engine trên Linux.
- Docker daemon (`dockerd`) đang chạy ổn định.
- Chạy các lệnh dưới đây từ thư mục gốc dự án (nơi chứa `Dockerfile`).

### Verify: Docker Engine đang chạy ổn định trên Linux

Lệnh:

```bash
systemctl status docker
```

**OK** khi thấy dòng trạng thái:

```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; ...)
     Active: active (running) since ...
```

Điểm cần chú ý: `Active: active (running)` (chấm tròn màu xanh lá ở đầu dòng nếu terminal hỗ trợ màu).

**Không OK** khi thấy:

```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; ...)
     Active: inactive (dead)
```

hoặc:

```
● docker.service - Docker Application Container Engine
     Loaded: loaded (/usr/lib/systemd/system/docker.service; enabled; ...)
     Active: failed (Result: exit-code) since ...
```

Có thể kiểm tra nhanh hơn (chỉ trả về đúng 1 từ):

```bash
systemctl is-active docker
```

- OK → in ra `active`
- Không OK → in ra `inactive` hoặc `failed`

Ngoài ra có thể verify daemon phản hồi được qua chính CLI Docker:

```bash
docker info
```

- OK → lệnh in ra một khối thông tin dài gồm `Server:`, `Containers:`, `Images:`, `Server Version:`, ... không có dòng lỗi.
- Không OK → in ra lỗi dạng:

```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```

## 1. Build image

```bash
docker build -t spring-boot-jvm-baseline:local .
```

- `-t spring-boot-jvm-baseline:local`: đặt tên (tag) cho image.
- `.`: build context là thư mục hiện tại.

**Lưu ý về thời gian:** đây là build đa giai đoạn (multi-stage) có tải dependency Gradle bên trong container, nên lần build đầu tiên thường mất khoảng **~3 phút** (tuỳ tốc độ mạng và cấu hình máy). Cứ để terminal chạy, không cần Ctrl+C giữa chừng.

### Verify: build thành công

Dòng **cuối cùng** trong output khi build xong sẽ có dạng:

```
=> => unpacking to docker.io/library/spring-boot-jvm-baseline:local
```

Đây là dấu hiệu build hoàn tất và image đã được gắn tag thành công.

**Không OK** nếu terminal dừng lại giữa chừng với dòng lỗi bắt đầu bằng `ERROR:`, ví dụ:

```
ERROR: failed to solve: process "/bin/sh -c ./gradlew bootJar --no-daemon -x test" did not complete successfully: exit code: 1
```

hoặc build dừng ở một bước `[build x/y]` mà không tiến tiếp và không có dòng `unpacking to ...` ở cuối.

### Verify: image đã có trong local image store

```bash
docker images | grep spring-boot-jvm-baseline
```

**OK** khi lệnh trả về đúng 1 dòng, ví dụ:

```
spring-boot-jvm-baseline:local   786de7abd009        342MB         93.4MB
```

**Không OK** khi lệnh không trả về dòng nào (không có output).

Build lại từ đầu, không dùng cache (khi nghi ngờ cache cũ gây lỗi):

```bash
docker build --no-cache -t spring-boot-jvm-baseline:local .
```

## 2. Chạy container

Chạy ở chế độ foreground (thấy log trực tiếp, `Ctrl+C` để dừng):

```bash
docker run --rm -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
```

### Verify: container khởi động thành công (foreground)

**OK** khi thấy các dòng log gần cuối:

```
Tomcat started on port 8080 (http) with context path '/'
Started SpringBootJvmBaselineApplication in ... seconds
```

**Không OK** khi terminal in ra stack trace Java (thường có dòng `***************************` hoặc `APPLICATION FAILED TO START`), hoặc container thoát ngay lập tức và quay lại dấu nhắc shell mà không có dòng `Started SpringBootJvmBaselineApplication`.

Chạy nền (detached):

```bash
docker run -d -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
```

- `-p 8080:8080`: map port `8080` của host sang port `8080` trong container.
- `--name jvm-baseline`: đặt tên container để dễ thao tác các lệnh sau.
- `--rm`: tự xoá container khi dừng (dùng khi chạy foreground/test nhanh).
- `-d`: chạy nền (detached mode).

### Verify: container đang chạy (detached)

```bash
docker ps --filter name=jvm-baseline
```

**OK** khi thấy đúng 1 dòng với cột `STATUS` bắt đầu bằng `Up`, ví dụ:

```
CONTAINER ID   IMAGE                             ...   STATUS          PORTS
a1b2c3d4e5f6   spring-boot-jvm-baseline:local    ...   Up 5 seconds    0.0.0.0:8080->8080/tcp
```

**Không OK** khi lệnh không trả về dòng container nào (chỉ có dòng header), nghĩa là container không ở trạng thái chạy.

## 3. Kiểm tra ứng dụng

```bash
curl http://localhost:8080/
```

**OK** khi kết quả trả về đúng chuỗi:

```
hello from Vietpq
```

**Không OK** khi nhận lỗi kết nối, ví dụ:

```
curl: (7) Failed to connect to localhost port 8080 after ...: Connection refused
```

Hoặc mở trình duyệt: `http://localhost:8080`

## 4. Xem log container

```bash
docker logs -f jvm-baseline
```

- `-f`: theo dõi log liên tục (follow).

**OK** khi thấy log Spring Boot đang chảy bình thường (các dòng `INFO ...`), không có dòng lỗi lặp lại liên tục.

**Không OK** khi thấy lỗi:

```
Error: No such container: jvm-baseline
```

(nghĩa là container tên `jvm-baseline` không tồn tại tại thời điểm chạy lệnh)

## 5. Xem danh sách container / image

Container đang chạy:

```bash
docker ps
```

Tất cả container (cả đã dừng):

```bash
docker ps -a
```

**OK** khi thấy dòng container `jvm-baseline` với cột `STATUS` là `Up ...` (đang chạy) hoặc `Exited (0) ...` (đã dừng bình thường).

**Không OK** khi cột `STATUS` là `Exited (1)` hoặc mã khác `0`, hoặc `Restarting`.

Danh sách image:

```bash
docker images
```

**OK** khi thấy dòng `spring-boot-jvm-baseline` với `TAG` là `local`.

## 6. Dừng / xoá container

Dừng container:

```bash
docker stop jvm-baseline
```

### Verify: container đã dừng

```bash
docker ps -a --filter name=jvm-baseline
```

**OK** khi cột `STATUS` hiển thị `Exited (0) ... seconds ago`.

**Không OK** khi cột `STATUS` vẫn hiển thị `Up ...` (container chưa thực sự dừng).

Khởi động lại container đã dừng (không tạo mới):

```bash
docker start jvm-baseline
```

**OK** khi lệnh in ra đúng tên container (`jvm-baseline`) và `docker ps` sau đó cho thấy `STATUS` là `Up ...`.

Xoá container (phải dừng trước hoặc dùng `-f`):

```bash
docker rm jvm-baseline
docker rm -f jvm-baseline
```

### Verify: container đã bị xoá

```bash
docker ps -a --filter name=jvm-baseline
```

**OK** khi lệnh không trả về dòng container nào (chỉ có dòng header).

**Không OK** khi vẫn còn thấy dòng chứa `jvm-baseline`.

## 7. Xoá image

```bash
docker rmi spring-boot-jvm-baseline:local
```

### Verify: image đã bị xoá

```bash
docker images | grep spring-boot-jvm-baseline
```

**OK** khi lệnh không trả về dòng nào.

**Không OK** khi vẫn trả về 1 dòng chứa `spring-boot-jvm-baseline:local` (image chưa bị xoá, ví dụ do vẫn còn container dùng image này).

## 8. Truy cập shell bên trong container (debug)

```bash
docker exec -it jvm-baseline sh
```

> Lưu ý: image runtime dùng base `alpine`, chỉ có `sh`, không có `bash`.

### Verify: đã vào được shell trong container

**OK** khi dấu nhắc lệnh đổi thành dạng:

```
/app $
```

**Không OK** khi nhận lỗi:

```
Error response from daemon: Container ... is not running
```

## 9. Dọn dẹp nhanh (khi cần build lại sạch)

Xoá container đã dừng, image không dùng, cache build:

```bash
docker system prune -f
```

> Cẩn thận: lệnh này xoá dữ liệu Docker không sử dụng trên toàn máy, không chỉ riêng project này.

### Verify: dung lượng đã được giải phóng

**OK** khi cuối output thấy dòng tổng kết dạng:

```
Total reclaimed space: 1.2GB
```

(con số tuỳ vào lượng dữ liệu rác trước đó; `0B` cũng là kết quả hợp lệ nếu không có gì để dọn)

## Tóm tắt quy trình thường dùng

```bash
docker build -t spring-boot-jvm-baseline:local .
docker run -d -p 8080:8080 --name jvm-baseline spring-boot-jvm-baseline:local
curl http://localhost:8080/
docker logs -f jvm-baseline
docker stop jvm-baseline
docker rm jvm-baseline
```
