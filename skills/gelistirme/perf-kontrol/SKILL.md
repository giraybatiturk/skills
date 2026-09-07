---
name: perf-kontrol
description: Bundle ve yükleme performansını bütçeye karşı ölçer, aşımın kaynağını bulur ve iyileştirme reçetelerini uygular. Bağımlılık eklenince ve yayın öncesi çalışır.
disable-model-invocation: true
---

# /perf-kontrol

Argüman: uygulama/varyant adı. Verilmezse projedeki tüm uygulamaları ölç.

**Ne zaman çalıştırılır**

- Yeni bir **bağımlılık** eklendiğinde; en sık bütçe aşımı buradan gelir
- Ağır bir ekran ya da grafik eklendiğinde
- Canlıya çıkmadan önce
- "Uygulama yavaşladı" denince

Ölçüm build çıktısı (`dist`) üzerinden yapılır; önce build gerekir. Kaynak dosyaya bakıp "preload eksik" demek yanlış çıkar; **ölçüm build çıktısında**.

## Bütçe

Önce projenin `DESIGN.md`'sine bak; performans bütçesi orada yazıyorsa o geçerli. Yazmıyorsa şu tabanı kullan ve ilk ölçümden sonra gerçek değerlerin üstüne makul pay ekleyerek `DESIGN.md`'ye yaz:

| Ölçü | Taban bütçe |
|---|---|
| İlk yükleme (gzip) | **≤ 220 KB** |
| Tek lazy chunk (ham) | **≤ 350 KB** |
| Varyantlar arası fark (çok markalıysa) | **≤ %10** |
| LCP · INP · CLS | **< 2.5s · < 200ms · < 0.1** (alan ölçümü ayrı) |

"İlk yükleme" = `index.html`'in doğrudan çektiği js + css. Lazy chunk'lar sayılmaz; onlar rotaya girilince iner.

Bütçe aşılırsa **dur ve raporla**. Aşımı sessizce kabul etmek, bir sonraki turda daha büyük aşımın normali olur.

## Ölçümler (kopyala-çalıştır)

`<dist>` yerine uygulamanın build dizinini koy.

```bash
# 1. İlk yükleme, gzip
d=<dist>; ham=0; gz=0
for f in $(grep -oE '/assets/[A-Za-z0-9_.-]+\.(js|css)' "$d/index.html" | sort -u); do
  p="$d$f"; [ -f "$p" ] || continue
  ham=$((ham + $(du -k "$p" | cut -f1)))
  gz=$((gz + $(gzip -c "$p" | wc -c) / 1024))
done
printf "%5s KB ham -> %4s KB gzip\n" "$ham" "$gz"

# 2. İlk yükleme kırılımı: hangi dosya ne kadar
for f in $(grep -oE '/assets/[A-Za-z0-9_.-]+\.(js|css)' "$d/index.html" | sort -u); do
  p="$d$f"; [ -f "$p" ] || continue
  printf "%5s KB gz  %s\n" "$(( $(gzip -c "$p" | wc -c) / 1024 ))" "$(basename $f)"
done | sort -rn

# 3. En büyük lazy chunk'lar
find <dist>/assets -name "*.js" -exec du -k {} + | sort -rn | head -10

# 4. Lazy chunk sayısı: kod bölme çalışıyor mu
find <dist>/assets -name "*.js" | wc -l

# 5. Bir bağımlılık kaç chunk'ta
grep -c "<paket-adı>" <dist>/assets/*.js 2>/dev/null | grep -v ":0" | head

# 6. Preload gerçekten basılıyor mu
grep -oE '<link rel="(preload|modulepreload)"[^>]*>' <dist>/index.html
```

## Aşım varsa nereye bakılır

Sıra önemli; üstteki daha büyük kazanç verir.

1. **İlk yüklemeye sızmış lazy içerik.** Bir rota bileşeni entry chunk'a girmişse kod bölme kopmuştur. `index-*.js` aniden büyüdüyse buraya bak: `grep -oE "[A-Z][a-zA-Z]+(Screen|Page)" <dist>/assets/index-*.js | sort -u`
2. **Yeni bağımlılık.** Aynı işi yapan bir şey zaten var mı (merdiven: stdlib → native platform → kurulu bağımlılık → yeni paket). İkinci bir tarih/ikon/tablo kütüphanesi hem bütçeyi hem tutarlılığı bozar.
3. **Sözlük dosyaları.** i18n sözlüğü büyükse `core`/`rest` diye bölünmeli; ilk yüklemede yalnız `core` inmeli.
4. **Grafik ve tablo kütüphaneleri.** Rota bazlı lazy kalması şart; dashboard dışı bir ekrana sızarsa taşır.
5. **Tekrarlanan vendor.** Aynı kütüphane iki chunk'ta birden varsa `manualChunks` yapılandırması gözden geçirilir. Emsal: `react-dom/client` alt yolu `'react-dom'` girdisiyle yakalanmıyordu, 498 KB istemci runtime'ı entry'de kalmıştı; alt yolu ayrı girdi yapmak çözdü.

## İyileştirme reçeteleri

### A. İlk yükleme büyükse

- **A1. Entry'ye sızmış rota.** `React.lazy` ile bölünmemiş ya da bir üst bileşen doğrudan import ediyor. En sık ve en büyük kazanç.
- **A2. Sözlük entry'de.** `grep -c "rest" <dist>/index.html` sıfır olmalı.
- **A3. Yeni bağımlılık.** Eklemeden önce merdiven.
- **A4. Çok küçük chunk'lar.** 1 KB'lık chunk'lar ayrı dosya olursa maliyet boyut değil **istek sayısıdır** (bir rota geçişi 14 istek açıyordu). `experimentalMinChunkSize` ile eritilir. Yeni rota eklendiğinde chunk sayısını kontrol et.

### B. İlk boya (LCP) yavaşsa

- **B1. Preload, ama seçici.** Yalnız ilk karede gereken font ve sözlük parçası. Emsal: iki mono font dosyası (44 KB) en yüksek öncelikte inip render'ın beklediği sözlük chunk'ını dalganın sonuna atıyordu; `rest` sözlüğü preload edilince login FCP'si 640'tan 1224 ms'ye çıkmıştı. Preload deseni dosya adına bağlıysa ad değişince **sessizce düşer**; her değişiklikten sonra ölçüm 6 ile doğrula.
- **B2. `font-display: swap`.** FOIT LCP'yi kaydırır.
- **B3. Kritik olmayan üçüncü parti ertelenir.** Analitik, chat widget, harita SDK'sı ilk boyayı bekletmez; yalnız kullanan kişide, yalnız bir kez iner.

### C. Algılanan performans

Ölçülen süre iyi ama **hissedilen** kötüyse:

- **C1. İskelet, spinner değil.** Gelecek düzeni taklit eden iskelet CLS'i keser. Kanon eşlemesi projenin DESIGN.md'sinde.
- **C2. Arka plan yenilemede içeriği değiştirme.** `isFetching` sırasında mevcut içerik iskeletle değiştirilmez; ince ilerleme çizgisi kullanılır.
- **C3. Optimistik UI.** 400 ms Doherty eşiğini tutmanın en ucuz yolu. Para ve kayıt yazan işlemlerde **kullanılmaz**.
- **C4. Büyük liste.** Sayfalama çoğu ekran için doğru; sanallaştırmaya yalnız sayfalanamayan uzun liste (pano, sohbet akışı) için geçilir.

### D. Doğrulama

Her iyileştirmeden sonra **yeniden ölç ve karşılaştır**. "Daha hızlı hissettiriyor" kanıt değil.

```
öncesi:  <n> KB gzip
sonrası: <n> KB gzip   (fark, %)
```

Bundle küçülmediyse değişiklik işe yaramamıştır; geri al ve başka reçeteye geç.

## Çıktı

```
Uygulama    İlk yükleme (gzip)   Bütçe    Durum
<ad>        <n> KB               220 KB   ✓ / ✗

En büyük lazy chunk: <ad> <boyut> (bütçe 350 KB)
Lazy chunk sayısı:   <n>
Build tarihi:        <tarih>

Aşım varsa: hangi dosya, ne kadar, muhtemel sebep, önerilen adım.
```

Ölçüm `dist` üzerinden yapıldığı için **build tarihini yaz**; eski `dist` ile ölçüm yanıltıcı olur.

## Kardeş skill'ler

| Skill | Ne zaman |
|---|---|
| `/yeni-ozellik` | Kod yazmadan önce |
| `/modul-kontrol` | Yazılmış modülde eksik senaryo avı |
| `/tasarim-kontrol` | Ekran bitince, görsel + DESIGN denetimi |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi (bu skill) |
| `/giray` | Hangisini kullanacağını bilmiyorsan |
