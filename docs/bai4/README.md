## Phần C – Kết quả quét lỗ hổng

| Image | Kích thước | HIGH | CRITICAL |
|---|---|---|---|
| node:22-alpine | 289 MB | 10 | 0 |
| node:22 | 1.67 GB | 479 | 20 |




## Phần D – Phân tích quyết định mở Network Access 0.0.0.0/0

| Hạng mục | Nội dung |
|---|---|
| Quyết định | Atlas cho phép kết nối từ mọi địa chỉ IP (0.0.0.0/0) |
| Lý do phải làm vậy | Codespaces và Vercel dùng IP động, không có dải IP cố định để thêm vào danh sách cho phép |
| Rủi ro cụ thể | Bất kỳ ai trên Internet đều có thể thử kết nối tới cụm; dò mật khẩu (brute force) hoặc dùng lỗ hổng của dịch vụ cơ sở dữ liệu; nếu chuỗi kết nối bị lộ thì kẻ tấn công dùng được ngay từ bất kỳ đâu; tăng bề mặt tấn công và nguy cơ bị tấn công từ chối dịch vụ |
| Biện pháp bù trừ đang có | (1) Người dùng DB chỉ có quyền readWrite trên một cơ sở dữ liệu, không phải quyền admin, nên thiệt hại bị giới hạn. (2) Mật khẩu ngẫu nhiên, dài, rất khó dò. (3) Atlas bắt buộc TLS nên dữ liệu trên đường truyền được mã hóa. (4) Bí mật nằm trong Codespaces Secrets, không nằm trong mã nguồn |
| Phương án tốt hơn nếu có ngân sách | IP tĩnh rồi chỉ cho phép đúng IP đó; hoặc Private Endpoint / VPC peering để lưu lượng đi qua mạng riêng, không đi qua Internet công cộng |
| Chi phí / đánh đổi | Cần gói trả phí (cụm Atlas cao hơn M0 miễn phí, gói Vercel cao hơn) và cấu hình phức tạp hơn |