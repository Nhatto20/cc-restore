# cc-restore

Mở lại các phiên Claude Code đã đóng (hoặc đang chạy) từ mọi thư mục, mỗi phiên một tab Windows Terminal.

Khác với `claude --resume` (chỉ thấy phiên của thư mục hiện tại), `cc-restore` liệt kê phiên của tất cả thư mục, mới nhất lên đầu.
Bạn chọn nhiều phiên cùng lúc, và mỗi phiên mở trong một tab mới, đúng thư mục gốc của nó.

## Yêu cầu

- Windows Terminal và WSL (đã test trên Debian).
- Trong WSL: `bash`, `jq`, `fzf` (bản 0.38 trở lên), `claude`.

## Cài đặt

```bash
sudo apt install jq fzf
git clone <repo-url> ~/cc-restore
~/cc-restore/install.sh
```

`install.sh` tạo hai symlink, nên sau này chỉ cần `git pull` là cập nhật:

| symlink | trỏ tới |
|---|---|
| `~/.local/bin/cc-restore` | `~/cc-restore/cc-restore` |
| `~/.claude/skills/restore` | `~/cc-restore/skill/restore` |

Script kiểm tra đủ lệnh cần thiết trước khi cài, và báo nếu `~/.local/bin` chưa có trong `PATH`.
Nếu đã có thư mục `~/.claude/skills/restore` thật (không phải symlink), script đổi tên nó thành `restore.bak.<timestamp>`.

## Sử dụng

Từ terminal WSL:

```bash
cc-restore
```

Trong Claude Code, gõ `/restore`.
Picker mở trong một tab mới và tự đóng khi bạn chọn xong.

| phím | tác dụng |
|---|---|
| gõ chữ | lọc theo tên project hoặc label |
| `TAB` | chọn hoặc bỏ chọn một phiên |
| `ENTER` | mở các phiên đã chọn, mỗi phiên một tab |
| `ESC` | thoát |

Mỗi dòng hiển thị: trạng thái, thời gian hoạt động cuối (`5m`, `3h`, `2d`), tên project và label.
Khung preview bên phải hiện đường dẫn, trạng thái và vài prompt gần nhất.

Label lấy theo thứ tự ưu tiên: tên đặt bằng `/rename`, tiêu đề AI tự sinh, tên phiên không tự sinh, prompt đầu tiên.

### Phiên đang chạy

Phiên đang chạy có dấu `●` màu xanh.
Khi mở lại một phiên đang chạy, script hỏi `[F]ork / [s]hared?`:

- `F` hoặc `ENTER`: mở bản sao với id mới (`claude --resume <id> --fork-session`). Phiên gốc giữ nguyên.
- `s`: mở chung id. Hai tab cùng ghi vào một transcript, nên có thể lẫn nội dung.

### Lệnh khác

```text
cc-restore --tab        mở picker trong một tab mới
cc-restore --list       in danh sách phiên: id, mtime, running, cwd, label
cc-restore --dry-run [--fork|--shared] <id>...   in lệnh wt.exe thay vì chạy
cc-restore --help
```

## Cấu hình

| biến | mặc định | ý nghĩa |
|---|---|---|
| `CC_RESTORE_PROFILE` | `Windows PowerShell` | Profile Windows Terminal quyết định giao diện tab mới (độ mờ, màu). Đặt rỗng để dùng profile mặc định của WT. |
| `WSL_DISTRO_NAME` | do WSL tự đặt | Distro mà tab mới chạy `claude`. |

Ví dụ, đặt trong `~/.bashrc`:

```bash
export CC_RESTORE_PROFILE="Debian"
```

Tên profile phải khớp đúng trường `name` trong settings của Windows Terminal, nếu không `wt.exe` báo lỗi.

## Gỡ cài đặt

```bash
rm ~/.local/bin/cc-restore ~/.claude/skills/restore
```

## Test

```bash
bash test/run.sh
```

Test dùng một `HOME` giả trong thư mục tạm, không đụng tới `~/.claude` thật.
Phần picker (fzf) và việc mở tab thật cần kiểm tra bằng tay.

## Xử lý sự cố

| triệu chứng | nguyên nhân và cách sửa |
|---|---|
| Tab mới báo không tìm thấy `claude` | Tab chạy `bash -lc`, nên `claude` phải nằm trong `PATH` của login shell (`~/.profile`). |
| Một tab lỗi `0x80070002` | `wt.exe` coi `;` là dấu tách lệnh. Script đã escape `;` trong tên và đường dẫn. Nếu tự sửa lệnh, đừng dùng `;`. |
| Picker chậm hiện | Script đọc toàn bộ transcript trong `~/.claude/projects`. Trên WSL đang tải nặng, việc này mất vài giây. |

Chi tiết thiết kế và định dạng dữ liệu nằm ở `docs/design.md`.
