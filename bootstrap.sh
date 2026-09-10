#!/usr/bin/env bash
# Sıfırdan Mac kurulumu. Tek komut:
#
#   curl -fsSL https://raw.githubusercontent.com/giraybatiturk/skills/main/bootstrap.sh | bash
#
# Ya da dotfiles zaten klonlanmışsa doğrudan:
#
#   bash ~/Developer/dotfiles/bootstrap.sh
#
# Yeniden çalıştırılabilir: her adım önce "zaten var mı" diye bakar, varsa atlar.
# Hiçbir adım sessizce başarısız olmaz; sonda bir özet tablosu basar.

set -uo pipefail

DEV="$HOME/Developer"
DOTFILES="$DEV/dotfiles"
SONUC=()

adim()  { printf "\n\033[1m── %s\033[0m\n" "$1"; }
tamam() { printf "   \033[32m✓\033[0m %s\n" "$1"; SONUC+=("✓ $1"); }
atla()  { printf "   \033[90m·\033[0m %s\n" "$1"; SONUC+=("· $1"); }
uyar()  { printf "   \033[33m!\033[0m %s\n" "$1"; SONUC+=("! $1"); }
hata()  { printf "   \033[31m✗\033[0m %s\n" "$1"; SONUC+=("✗ $1"); }

# ── 1. Xcode komut satırı araçları ──────────────────────
# git buna bağlı, ilk sırada olmalı.
adim "Xcode komut satırı araçları"
if xcode-select -p >/dev/null 2>&1; then
  atla "zaten kurulu"
else
  xcode-select --install 2>/dev/null || true
  echo "   Açılan pencerede kurulumu tamamla, bitince Enter'a bas."
  read -r
  xcode-select -p >/dev/null 2>&1 && tamam "kuruldu" || hata "kurulamadı, elle: xcode-select --install"
fi

# ── 2. Homebrew ─────────────────────────────────────────
adim "Homebrew"
if command -v brew >/dev/null 2>&1; then
  atla "zaten kurulu"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true
  command -v brew >/dev/null 2>&1 && tamam "kuruldu" || { hata "Homebrew kurulamadı, durduruldu"; exit 1; }
fi
eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || true

# ── 3. GitHub girişi ────────────────────────────────────
# dotfiles deposu private, bu adım olmadan klonlanamaz.
adim "GitHub girişi"
command -v gh >/dev/null 2>&1 || brew install gh
if gh auth status >/dev/null 2>&1; then
  atla "zaten giriş yapılmış"
else
  echo "   Tarayıcı açılacak, GitHub hesabınla giriş yap."
  gh auth login --hostname github.com --git-protocol https --web
  gh auth status >/dev/null 2>&1 && tamam "giriş yapıldı" || { hata "giriş yapılamadı, durduruldu"; exit 1; }
fi
gh auth setup-git 2>/dev/null && tamam "git kimlik yardımcısı ayarlandı"

# ── 4. Depolar ──────────────────────────────────────────
adim "Depolar"
mkdir -p "$DEV"
klonla() {
  local ad="$1" hedef="$DEV/$1"
  if [[ -d "$hedef/.git" ]]; then atla "$ad zaten var"
  elif gh repo clone "giraybatiturk/$ad" "$hedef" -- --quiet 2>/dev/null; then tamam "$ad klonlandı"
  else hata "$ad klonlanamadı"; fi
}
klonla dotfiles
klonla skills
klonla brain

# ── 5. Paketler ─────────────────────────────────────────
adim "Homebrew paketleri"
if [[ -f "$DOTFILES/Brewfile" ]]; then
  brew bundle --file="$DOTFILES/Brewfile" --no-lock 2>&1 | tail -3
  tamam "Brewfile kuruldu ($(grep -c '^brew\|^cask' "$DOTFILES/Brewfile") paket)"
else
  hata "Brewfile bulunamadı"
fi

# ── 6. Node ─────────────────────────────────────────────
adim "Node"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env)" 2>/dev/null || true
  if fnm list 2>/dev/null | grep -q "v2[0-9]"; then atla "zaten kurulu"
  else fnm install --lts && fnm default lts-latest && tamam "LTS kuruldu"; fi
else
  uyar "fnm yok, Node kurulmadı"
fi

# ── 7. Claude Code ──────────────────────────────────────
adim "Claude Code"
if command -v claude >/dev/null 2>&1; then
  atla "zaten kurulu"
else
  curl -fsSL https://claude.ai/install.sh | bash && tamam "kuruldu" || uyar "kurulamadı, elle: claude.ai/install.sh"
fi

# ── 8. Yapılandırma ─────────────────────────────────────
# restore.sh symlink'leri, hafızayı, görevleri, launchd'yi kurar ve
# real-* skill'lerini ~/Developer/skills klonundan linkler.
adim "Yapılandırma (restore.sh)"
if [[ -f "$DOTFILES/claude/restore.sh" ]]; then
  bash "$DOTFILES/claude/restore.sh" && tamam "symlink, hafıza, görevler, skill'ler kuruldu"
else
  hata "restore.sh bulunamadı"
fi

# ── 9. Doğrulama ────────────────────────────────────────
adim "Doğrulama"
n=$(ls -d "$HOME"/.claude/skills/real-* 2>/dev/null | wc -l | tr -d ' ')
[[ "$n" == "8" ]] && tamam "8 real-* skill kurulu" || uyar "$n real-* skill bulundu, 8 bekleniyordu"
[[ -L "$HOME/.claude/CLAUDE.md" ]] && tamam "CLAUDE.md bağlı" || uyar "CLAUDE.md symlink'i yok"
[[ -f "$HOME/Library/LaunchAgents/com.giray.beyin-derleyici.plist" ]] && tamam "gece derleyici yüklü" || uyar "launchd görevi yok"

# ── Özet ────────────────────────────────────────────────
printf "\n\033[1m════ Özet ════\033[0m\n"
printf "%s\n" "${SONUC[@]}" | sed 's/^/  /'

cat <<'SON'

════ Elle kalanlar ════

Bu betiğin yapamayacağı üç şey var:

1. Keychain, iki şifre. Uygulama şifresi ve PostHog anahtarı:
     security add-generic-password -s brain-gmail -a giray@batiturk.com -w
     security add-generic-password -s brain-posthog -w

2. iCloud yedeğinden gizli dosyalar. Format-Yedek klasöründen:
     400-Vault klasörü  -> ~/Developer/brain/400 🔐 Vault/
     env/ içindekiler   -> kendi depolarına (.env.local, .dev.vars)

3. Claude Code girişi ve MCP yetkileri:
     claude  ile başlat, hesabınla giriş yap
     /mcp    ile bağlayıcıları yeniden yetkilendir

Sonra yeni bir oturumda /real- yaz. Sekiz skill çıkmalı.
SON
