# Benchmark: JVM vs GraalVM native cold start

Chuẩn đo dùng chung cho cả 2 repo được định nghĩa ở [spring-boot-graalvm-baseline/docs/benchmark.md](https://github.com/VietPam/spring-boot-graalvm-baseline/blob/master/docs/benchmark.md) — tài liệu này chạy **đúng script đó, không sửa logic**, chỉ khác image build ra từ repo này (JVM), và ghi lại kết quả thực đo của repo `spring-boot-jvm-baseline`.

## Script đo

[scripts/cold-start-benchmark.sh](../scripts/cold-start-benchmark.sh) — copy nguyên vẹn từ repo `spring-boot-graalvm-baseline`, tự build image, chạy N trial, đo, in kết quả tổng hợp + ghi raw CSV vào `scripts/results/` (không commit, xem `.gitignore`).

```bash
./scripts/cold-start-benchmark.sh
```

Biến môi trường có thể override: `TRIALS` (mặc định 10), `PORT` (mặc định 18080), `READY_TIMEOUT_S` (mặc định 30s).

## Định nghĩa từng metric

Xem đầy đủ định nghĩa từng metric và giới hạn của cách đo local (không phải số thật trên Render) tại [benchmark.md bên repo GraalVM](https://github.com/VietPam/spring-boot-graalvm-baseline/blob/master/docs/benchmark.md#định-nghĩa-từng-metric) — không lặp lại ở đây để tránh 2 bản dễ lệch nhau theo thời gian.

## Môi trường đo (lần chạy dưới đây)

- Host: Linux x86_64, `7.0.0-29-generic` — **cùng máy** với lần đo bên GraalVM, đảm bảo so sánh công bằng.
- CPU: 12 cores, RAM: 30Gi
- Docker Engine: 29.6.2
- Ngày đo: 2026-08-12

## Kết quả — spring-boot-jvm-baseline (JVM, Eclipse Temurin 25)

| Metric | Giá trị |
|---|---|
| Build time (no cache) | 109.68s (~1 phút 50 giây) |
| Image content size | 93.4 MB |
| Image disk usage | 342 MB |
| Cold start — min | 3262.4 ms |
| Cold start — median | 3494.4 ms |
| Cold start — mean | 3762.4 ms |
| Cold start — max | 4793.7 ms |
| Self-reported Spring Boot startup (mean) | 2.861 s |
| Memory RSS lúc idle (mean) | 157.3 MiB |

10/10 trial thành công (không trial nào timeout/lỗi). Raw CSV của lần chạy này: `scripts/results/spring-boot-jvm-baseline-20260812-194532.csv` (không commit, chạy lại script để tái tạo).

## So sánh với spring-boot-graalvm-baseline

| Metric | JVM (repo này) | GraalVM native | Chênh lệch |
|---|---|---|---|
| Build time (no cache) | 109.68s | 364.14s | GraalVM build **chậm hơn ~3.3x** |
| Image content size | 93.4 MB | 35.6 MB | GraalVM **nhỏ hơn ~2.6x** |
| Image disk usage | 342 MB | 139 MB | GraalVM **nhỏ hơn ~2.5x** |
| Cold start — median | 3494.4 ms | 516.0 ms | GraalVM **nhanh hơn ~6.8x** |
| Cold start — mean | 3762.4 ms | 553.7 ms | GraalVM **nhanh hơn ~6.8x** |
| Self-reported startup (mean) | 2.861 s | 0.103 s | GraalVM **nhanh hơn ~27.8x** |
| Memory RSS idle (mean) | 157.3 MiB | 31.2 MiB | GraalVM **dùng ít hơn ~5.0x** |

## Kết luận

Trên cùng 1 máy, cùng phương pháp đo (Docker local, `docker run` → HTTP 200 đầu tiên, n=10):

- **GraalVM native thắng áp đảo ở đúng câu hỏi ban đầu (cold start)**: nhanh hơn JVM khoảng **6.8 lần** (553.7ms so với 3762.4ms, tính theo mean). Đây là kết quả mong đợi — native image không cần JIT warm-up hay class loading lúc runtime.
- **Đánh đổi nằm ở build time**: GraalVM build lâu hơn JVM khoảng **3.3 lần** (364s so với 110s) do phải compile ahead-of-time toàn bộ classpath thành machine code. Chi phí này chỉ trả 1 lần lúc CI build image, **không ảnh hưởng** đến trải nghiệm cold start thực tế của người dùng cuối — nên với mục tiêu ban đầu (tối ưu cold start trên Render free tier), đây là đánh đổi hợp lý.
- **Memory và image size đều nghiêng về GraalVM** (~5x ít RAM hơn, ~2.5-2.6x nhẹ hơn) — có lợi thêm cho gói Free của Render vốn giới hạn RAM chặt, giảm nguy cơ bị OOM-kill.
- Con số self-reported startup (2.861s JVM vs 0.103s GraalVM) chênh lệch còn lớn hơn cả cold start tổng — vì cold start còn gồm overhead khởi động container (kéo image, tạo network namespace...) là chi phí chung cho cả 2 bên, làm tỷ lệ chênh lệch "co lại" một chút so với riêng thời gian app tự khởi động.

**Số đo trên đều là local (Docker), không phải số thật trên Render** — theo đúng giới hạn đã nêu ở tài liệu gốc bên GraalVM. Câu trả lời cuối cùng cho câu hỏi ban đầu nằm ở phần validate thật bên dưới.

## Validate trên Render thật

Phương pháp: để service ngủ đủ lâu do không có traffic (Render free tier tự spin down sau ~15 phút idle), rồi gọi:

```bash
curl -s -o /dev/null -w "%{time_total}\n" https://<ten-service>.onrender.com/
```

### Kết quả — spring-boot-jvm-baseline (đo thủ công trên Render thật)

**Cold start sau khi service ngủ do inactive: ~60 giây** (`time_total` đo bằng lệnh trên).

So với số local (`docker run` → HTTP 200, mean 3.76s) thì chậm hơn khoảng **~16x**. Chênh lệch lớn này đến từ phần mà benchmark local hoàn toàn không đo được: Render phải **de-provision compute hoàn toàn khi service ngủ**, nên lúc thức dậy không chỉ là "start lại container" (như `docker run` trên máy đã có sẵn compute), mà còn gồm cấp phát compute mới, kéo image, network routing — đây chính là phần overhead nền tảng hosting free-tier mà 2 baseline muốn đo tác động lên JVM khác GraalVM ra sao.

### Log tham khảo (không phải số đo chính thức ở trên)

Log dưới đây là 1 lần **redeploy do tạo git tag mới** (kích hoạt qua `deploy` job → Render Deploy Hook), **không phải** do Render tự cho ngủ vì inactive — nên **không dùng số này thay cho số ~60s ở trên**. Vẫn hữu ích để minh hoạ cấu trúc thời gian bên trong 1 lần cold start trên Render (kiến trúc tương tự: container khởi động lại từ đầu), gồm 2 lần start liên tiếp cách nhau ~6 phút 40 giây trong cùng 1 log — lần đầu (11:42) là lần deploy khởi tạo service, có kèm 1 lần Render tự restart do phát hiện port mới nên bỏ qua không tính; lần sau (11:51) sạch hơn, dùng để tham khảo:

| Mốc | Timestamp | Ghi chú |
|---|---|---|
| `Starting service...` | 11:51:29.146 | Render bắt đầu cấp phát/khởi động container |
| `Starting SpringBootJvmBaselineApplication...` | 11:51:51.188 | JVM process bắt đầu chạy (log đầu tiên của app) |
| `Started ... in 36.899 seconds` | 11:52:18.586 | App tự báo cáo đã sẵn sàng |
| `Your service is live 🎉` | 11:52:20.234 | Render xác nhận route traffic vào được |

Tổng thời gian ví dụ này (`Starting service` → `service is live`): **~51.1 giây** — cùng bậc độ lớn với số ~60s đo riêng ở trên, dù nguyên nhân restart khác nhau (redeploy do tag, không phải do ngủ vì inactive).

### So sánh với spring-boot-graalvm-baseline trên Render thật

_Chưa có — cần lặp lại đúng phương pháp (`curl -w "%{time_total}"` sau khi service ngủ do inactive) trên service GraalVM đã deploy để điền vào đây._
