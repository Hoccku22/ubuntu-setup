
---

## 📜 Файл: `setup.sh` (улучшенная, идемпотентная версия)

```bash
#!/bin/bash
# ubuntu-setup — Hoccku22
# License: MIT

set -euo pipefail

# Цвета для логов
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[*]${NC} $1"; }
ok() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err() { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }

# === Настройки ===
USERNAME="hoccku22"
FULLNAME="Hoccku22"
PASSWORD_PLAIN="123"  # ← ЗАМЕНИ НА ХЕШ В ПРОДАКШЕНЕ!
HOSTNAME="ubuntu-pc"
TIMEZONE="Asia/Barnaul"

log "Проверка прав: требуется root"
[[ $EUID -ne 0 ]] && err "Запускай с sudo! Пример: sudo ./setup.sh"

# --- 1. Hostname ---
log "Устанавливаю hostname: $HOSTNAME"
hostnamectl set-hostname "$HOSTNAME"
grep -q "$HOSTNAME" /etc/hosts || echo "127.0.1.1 $HOSTNAME" >> /etc/hosts
ok "Hostname установлен"

# --- 2. Часовой пояс ---
log "Устанавливаю часовой пояс: $TIMEZONE"
timedatectl set-timezone "$TIMEZONE" && ok "Часовой пояс установлен"

# --- 3. Локали ---
log "Генерирую локали ru_RU.UTF-8 и en_US.UTF-8"
locale-gen ru_RU.UTF-8 en_US.UTF-8 > /dev/null
update-locale LANG=en_US.UTF-8 LANGUAGE="en_US:ru_RU" > /dev/null
ok "Локали сгенерированы"

# --- 4. Пользователь ---
if ! id "$USERNAME" &>/dev/null; then
    log "Создаю пользователя $USERNAME"
    useradd -m -s /bin/bash -c "$FULLNAME" "$USERNAME"
    echo "$USERNAME:$PASSWORD_PLAIN" | chpasswd
    usermod -aG sudo,adm,audio,video,plugdev,docker "$USERNAME" 2>/dev/null || true
    ok "Пользователь $USERNAME создан"
else
    warn "Пользователь $USERNAME уже существует"
fi

# --- 5. Обновление системы ---
log "Обновляю пакеты"
apt update -qq && apt upgrade -y -qq > /dev/null
ok "Система обновлена"

# --- 6. Установка приложений ---

# Yandex Browser
if ! command -v yandex-browser &>/dev/null; then
    log "Устанавливаю Yandex Browser"
    wget -qO- "https://repo.yandex.ru/yandex-browser/YANDEX-BROWSER-KEY.GPG" | gpg --dearmor >/usr/share/keyrings/yandex-browser.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/yandex-browser.gpg] https://repo.yandex.ru/yandex-browser/deb/ stable main" > /etc/apt/sources.list.d/yandex-browser.list
    apt update -qq
    apt install -y yandex-browser-stable
    ok "Yandex Browser установлен"
else
    warn "Yandex Browser уже установлен"
fi

# Telegram (Flatpak)
if ! flatpak list | grep -q "org.telegram.desktop"; then
    log "Устанавливаю Telegram (Flatpak)"
    if ! command -v flatpak &>/dev/null; then
        apt install -y flatpak > /dev/null
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
    runuser -l "$USERNAME" -c "flatpak install -y flathub org.telegram.desktop" > /dev/null
    ok "Telegram установлен"
else
    warn "Telegram уже установлен"
fi

# PyCharm Community
if ! snap list | grep -q pycharm-community; then
    log "Устанавливаю PyCharm Community (snap)"
    apt install -y snapd > /dev/null
    snap install pycharm-community --classic
    ok "PyCharm установлен"
else
    warn "PyCharm уже установлен"
fi

# --- 7. Настройки GNOME (от имени пользователя) ---
log "Применяю настройки GNOME для $USERNAME"

runuser -l "$USERNAME" -c "
    export DBUS_SESSION_BUS_ADDRESS=\"unix:path=/run/user/\$(id -u)/bus\"

    # Раскладка: ru/us + Alt+Shift / Shift+Alt
    gsettings set org.gnome.desktop.input-sources xkb-options \"['grp:alt_shift_toggle', 'grp:shift_alt_toggle']\"
    gsettings set org.gnome.desktop.input-sources sources \"[('xkb', 'us'), ('xkb', 'ru')]\" 2>/dev/null || true

    # Тёмная тема
    gsettings set org.gnome.desktop.interface gtk-theme 'Yaru-dark'
    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'

    # Показывать секунды в часах (опционально)
    gsettings set org.gnome.desktop.interface clock-show-seconds true
" || warn "⚠️ Настройки GNOME не применены (возможно, сессия не запущена)"

ok "Настройки GNOME применены (проверь после входа в систему)"

# === Готово ===
echo
echo -e "${GREEN}✅ Всё готово!${NC}"
echo "— Перезагрузи систему: ${BLUE}sudo reboot${NC}"
echo
echo "💡 Совет: замени пароль '123' командой:"
echo "   sudo passwd hoccku22"
