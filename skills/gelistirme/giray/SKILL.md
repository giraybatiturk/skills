---
name: giray
description: Bu repodaki skill'lerin giriş noktası ve haritası. Hangisini kullanacağını sorar ya da isteğe göre kendisi seçer ve çalıştırır.
disable-model-invocation: true
---

# /giray

Argümansız çağrılırsa: **sor, sonra çalıştır.** Argümanla çağrılırsa doğrudan o işe git. Kullanıcı ne istediğini zaten yazmışsa (ör. `/giray mesajlaşma modülünü denetle`) sorma, uygun skill'i seç ve söyle: "`/modul-kontrol` çalıştırıyorum."

## Ana akış: fikir → ürün

```
fikir      /grill-with-docs        fikri röportajla keskinleştir, CONTEXT.md + ADR
kapı       /yeni-ozellik           beş başlık, sekiz sınıf senaryo, onay; kod yazılmaz
plan       /to-spec  →  /to-tickets   çok oturumluk işse; tek oturumluksa doğrudan /implement
kod        /implement              içinde /tdd (dilim dilim) ve /code-review (standart + spec)
denetim    /modul-kontrol  →  /tasarim-kontrol  →  /perf-kontrol
```

Bağlam kuralı: fikir, kapı ve plan **tek bağlam penceresinde** kalır; `/to-tickets`'a kadar compact/clear yok. Her `/implement` sıfırdan, ticket'tan başlar.

Bir soru sohbette çözülemiyorsa (durum modeli, görülmesi gereken UI): `/prototype` ile atılabilir kod, cevap geri döner.

## Yan girişler

- **Gelen bug/istek yığını** → `/triage`. Yalnız senin açmadığın issue'lar için; `/to-tickets` çıktısını triage etme.
- **Bir şey bozuk** → `/diagnosing-bugs`. Önce kırmızı veren tek komut, sonra teori. Düzeltince `/modul-kontrol`: **aynı sınıftan başka ne var?**
- **Yeni paket eklendi / yavaşladı** → `/perf-kontrol`.
- **Ekran nasıl görünüyor** → `/tasarim-kontrol`.
- **Canlıya çıkacağız** → `/modul-kontrol`, `/tasarim-kontrol`, `/perf-kontrol` sırayla.
- **Repo yok, sadece fikir** → `/grill-me` (stateless röportaj).
- **Docs ve API gerçeklerini toplamak** → `/research`, arka planda.

## İlk kurulum

Repoda bir kez `/setup`: issue tracker (GitHub / GitLab / lokal markdown), triage etiketleri, `CONTEXT.md` + ADR düzeni. `/to-tickets`, `/triage`, `/to-spec` bunu okur.

## Tablo

| Skill | Ne zaman | Çağıran |
|---|---|---|
| `/setup` | Repoda bir kez | sen |
| `/grill-with-docs` · `/grill-me` | Fikri keskinleştir | sen |
| `/yeni-ozellik` | Kod yazmadan önce | sen |
| `/to-spec` · `/to-tickets` | Çok oturumluk plan | sen |
| `/implement` | Ticket'ı uygula | sen |
| `/triage` | Gelen issue yığını | sen |
| `/modul-kontrol` | Yazılmış modülde eksik senaryo | sen |
| `/tasarim-kontrol` | Ekran bitince | sen |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi | sen |
| `tdd` · `code-review` · `diagnosing-bugs` · `prototype` · `research` · `grilling` · `tasarim-kurallari` | Konu eşleşince | model |

Kurulu olmayan bir skill'e yönlendireceksen "kurulu değil" de, akışın kalanıyla devam et.

## Projeye özel komutlar

Projenin kendi komutları varsa (`.claude/commands/`, `AGENTS.md` içindeki tablo) onları da listeye ekle ve aynı soruda sun. Yayın akışı, backend istek kalıbı gibi işler proje repo'sunda yaşar, burada değil.
