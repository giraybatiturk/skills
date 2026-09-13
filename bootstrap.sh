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

# set -u YOK, bilerek: macOS'un bash'i 3.2 ve orada `set -u` ile boş bir
# dizinin "${A[@]}" açılımı "unbound variable" verip betiği öldürüyor.
# Ölçüldü: /bin/bash -c 'set -u; A=(); printf "%s" "${A[@]}"' patlıyor.
set -o pipefail

DEV="$HOME/Developer"
DOTFILES="$DEV/dotfiles"
SONUC=()

adim()  { printf "\n\033[1m── %s\033[0m\n" "$1"; }
tamam() { printf "   \033[32m✓\033[0m %s\n" "$1"; SONUC+=("✓ $1"); }
atla()  { printf "   \033[90m·\033[0m %s\n" "$1"; SONUC+=("· $1"); }
uyar()  { printf "   \033[33m!\033[0m %s\n" "$1"; SONUC+=("! $1"); }
hata()  { printf "   \033[31m✗\033[0m %s\n" "$1"; SONUC+=("✗ $1"); }

# Apple Silicon /opt/homebrew, Intel /usr/local. İkisini de dene.
brew_yolu() {
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x "$b" ]] && eval "$("$b" shellenv)" && return 0
  done
  return 1
}

# ── 1. Homebrew ─────────────────────────────────────────
# Xcode komut satırı araçları ayrı bir adım değil: Homebrew'un kurulum betiği
# eksikse onları da kuruyor, üstelik softwareupdate ile, GUI penceresi
# açmadan. Ayrı bir `xcode-select --install` iki fazladan adım demekti.
adim "Homebrew (Xcode araçları dahil)"
if command -v brew >/dev/null 2>&1; then
  atla "zaten kurulu"
else
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  brew_yolu
  command -v brew >/dev/null 2>&1 && tamam "kuruldu" || { hata "Homebrew kurulamadı, durduruldu"; exit 1; }
fi
brew_yolu

# ── 2. GitHub girişi ────────────────────────────────────
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

# ── 3. Depolar ──────────────────────────────────────────
adim "Depolar"
mkdir -p "$DEV"
klonla() {
  local ad="$1" hedef="$DEV/$1"
  if [[ -d "$hedef/.git" ]]; then atla "$ad zaten var"
  elif gh repo clone "giraybatiturk/$ad" "$hedef" -- --quiet; then tamam "$ad klonlandı"
  else hata "$ad klonlanamadı"; fi
}
klonla dotfiles
klonla skills
klonla brain

# ── 4. Paketler ─────────────────────────────────────────
# Tek satır, Brewfile yok. Ölçüm: 10 Eylül 2026, çalışan makinede `brew list`.
# 119 formülün 90'ı bağımlılık olarak geliyor (cairo, harfbuzz, libpng...),
# onlar yazılmadı; brew aşağıdakilerle birlikte kendisi kuruyor.
adim "Homebrew paketleri"
brew install \
  starship zsh-autosuggestions zsh-syntax-highlighting atuin zoxide fzf \
  eza bat fd ripgrep tmux jq \
  gh glab git-delta git-filter-repo \
  fnm python@3.14 pipx uv go deno \
  xcodegen asc idb-companion sentry-cli \
  poppler qpdf weasyprint tectonic ffmpeg yt-dlp unar \
  gnupg cliclick macmon 2>&1 | tail -2 || { hata "Homebrew formülleri kurulamadı, durduruldu"; exit 1; }
tamam "34 formül"

brew install --cask \
  ghostty font-jetbrains-mono font-jetbrains-mono-nerd-font \
  1password-cli gcloud-cli logi-options+ 2>&1 | tail -2 || { hata "Homebrew uygulamaları kurulamadı, durduruldu"; exit 1; }
tamam "6 uygulama"

# Ne neye yarıyor, silmeden önce bak:
#   poppler        pdftotext, brain/.claude/scripts/ekstre.py buna bağlı
#   glab           GitLab CLI, bibulut-web ve bilandings
#   xcodegen       project.yml -> xcodeproj, beebo/dosehue/vera
#   asc            App Store Connect CLI, yayın hattı
#   idb-companion  simülatör otomasyonu
#   sentry-cli     dSYM yükleme
#   ripgrep        Claude Code da kullanıyor
#   weasyprint     HTML -> PDF
#   tectonic       LaTeX
#   cliclick       ekran otomasyonu

# ── 5. Node ─────────────────────────────────────────────
adim "Node"
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env)" 2>/dev/null || true
  if fnm list 2>/dev/null | grep -q "v2[0-9]"; then atla "zaten kurulu"
  else fnm install --lts && fnm default lts-latest && tamam "LTS kuruldu"; fi
else
  uyar "fnm yok, Node kurulmadı"
fi

# ── 6. Claude Code ──────────────────────────────────────
adim "Claude Code"
if command -v claude >/dev/null 2>&1; then
  atla "zaten kurulu"
else
  curl -fsSL https://claude.ai/install.sh | bash && tamam "kuruldu" || uyar "kurulamadı, elle: claude.ai/install.sh"
fi

# ── 7. Yapılandırma ─────────────────────────────────────
# restore.sh symlink'leri, hafızayı, görevleri, launchd'yi kurar ve
# real-* skill'lerini ~/Developer/skills klonundan linkler.
adim "Yapılandırma (restore.sh)"
if [[ -f "$DOTFILES/claude/restore.sh" ]]; then
  bash "$DOTFILES/claude/restore.sh" && tamam "symlink, hafıza, görevler, skill'ler kuruldu" || exit 1
else
  hata "restore.sh bulunamadı"
  exit 1
fi

# ── 8. Doğrulama ────────────────────────────────────────
adim "Doğrulama"
for kok in "$HOME/.claude/skills" "$HOME/.agents/skills"; do
  eksik=""
  for ad in real-start real-plan real-audit real-research; do
    hedef="$kok/$ad"
    [[ -L "$hedef" && -f "$hedef/SKILL.md" ]] || eksik="$eksik $ad"
  done
  for ref in design-rules orchestration product module design performance security quality motion reporting monetization product-context; do
    [[ -f "$kok/real-audit/references/$ref.md" ]] || eksik="$eksik audit/$ref"
  done
  for ref in discovery feature-gate; do
    [[ -f "$kok/real-plan/references/$ref.md" ]] || eksik="$eksik plan/$ref"
  done
  if [[ -n "$eksik" ]]; then hata "$kok eksik veya bozuk:$eksik"; exit 1; fi
  tamam "$kok: dört workflow ve referansları doğrulandı"
done
[[ -L "$HOME/.claude/CLAUDE.md" ]] && tamam "CLAUDE.md bağlı" || uyar "CLAUDE.md symlink'i yok"
[[ -f "$HOME/Library/LaunchAgents/com.giray.beyin-derleyici.plist" ]] && tamam "gece derleyici yüklü" || uyar "launchd görevi yok"

# ── Özet ────────────────────────────────────────────────
printf "\n\033[1m════ Özet ════\033[0m\n"
[[ ${#SONUC[@]} -gt 0 ]] && printf "%s\n" "${SONUC[@]}" | sed 's/^/  /'

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

Sonra yeni bir oturumda /real- yaz. Dört public skill çıkmalı: start, plan, audit, research.
SON
