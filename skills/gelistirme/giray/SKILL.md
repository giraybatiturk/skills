---
name: giray
description: Giray'ın iş akışı skill'lerinin giriş noktası. Hangisini kullanacağını sorar ya da isteğe göre kendisi seçer ve çalıştırır.
disable-model-invocation: true
---

# /giray

Argümansız çağrılırsa: **sor, sonra çalıştır.** Argümanla çağrılırsa doğrudan o işe git. Kullanıcı ne istediğini zaten yazmışsa (ör. `/giray mesajlaşma modülünü denetle`) sorma, uygun skill'i seç ve söyle: "`/modul-kontrol` çalıştırıyorum."

## Skill'ler

| Skill | Ne zaman | Ne yapar |
|---|---|---|
| `/yeni-ozellik` | Kod yazmadan **önce** | Niyet keşfi, mevcut durum ölçümü, sekiz sınıfta senaryo, beş başlık, onay kapısı |
| `/modul-kontrol` | Yazılmış modülde | Eksik senaryo avı: yetki aksiyonları, durum geçişleri, hata yolları, boş haller |
| `/tasarim-kontrol` | Ekran bitince | Ekran görüntüsü + kod üzerinden DESIGN.md uyumluluk denetimi, puanla, düzelt |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi | Bundle bütçesi denetimi; aşımın hangi chunk'tan geldiğini gösterir |

Seçim yardımı:

- "Yeni bir şey yapacağım" → `/yeni-ozellik`
- "Bu modülde ne eksik?" → `/modul-kontrol`
- "Ekran nasıl görünüyor?" → `/tasarim-kontrol`
- "Canlıya çıkacağız" → önce `/modul-kontrol`, sonra `/tasarim-kontrol`, sonra `/perf-kontrol`
- "Yeni paket ekledim" ya da "yavaşladı" → `/perf-kontrol`

**Skill değil ama aynı refleksin parçası** (kuruluysa):

- "Şu çalışmıyor, sebebini bilmiyorum" → `superpowers:systematic-debugging`. Fix önermeden ÖNCE. Ölçülmeden söylenen teşhis, boşa giden bir backend isteğine dönüşür.
- "Bitti sayabilir miyiz?" → `superpowers:verification-before-completion`. "Çalışıyor" demeden önce gerçekten çalıştığını gör.
- Bir hata bulundu ve düzeltildi → ardından `/modul-kontrol`: **aynı sınıftan başka ne var?** Tek hatayı düzeltip geçmek, kardeşlerini kullanıcıya buldurmak demek.

## Projeye özel komutlar

Projenin kendi komutları varsa (`.claude/commands/`, `.Codex/commands/`, `AGENTS.md` içindeki tablo) onları da listeye ekle ve aynı soruda sun. Yayın akışı, backend istek kalıbı gibi işler proje repo'sunda yaşar, burada değil.

## Adlandırma kuralı

Türkçe, tire ile ayrık, fiil ya da isim öbeği. Denetim yapanlar `-kontrol` ile biter.
