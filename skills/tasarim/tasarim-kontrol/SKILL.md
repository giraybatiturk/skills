---
name: tasarim-kontrol
description: Bir ekranı ekran görüntüsü + kod üzerinden projenin DESIGN.md kurallarına karşı denetler, 9 boyutta puanlar, onayla düzeltir. Ekran bitince çalışır.
disable-model-invocation: true
---

# /tasarim-kontrol

Argüman: bir ekran/dosya yolu ya da adı (ör. `VoucherEntryScreen`). **Verilmezse preview'da açık olan ekranı denetle**: kullanıcının paylaştığı ekran görüntüsü / URL'den route'u çöz ve sormadan onun üstünden git. İkisi de yoksa hangi ekran diye sor.

Kural kaynağı: projenin `DESIGN.md`'si. Yoksa `tasarim-kurallari` skill'i taban olur. **Uydurma kural ekleme.**

## Akış

0. **Görsel ile başla.** Statik kodun yakalayamadığı boşluk düzeni (kutu-kutu gap, buton padding, kenar yakınlığı), hizalama, ritim, renk/radius, durum ve tutarlılık yalnız render'da belli olur. Kullanıcı preview'den ss paylaşır ya da kuruluysa headless capture kullanılır; **kullanıcının aktif tarayıcısı o an açıkça izin verilmedikçe otomatikleştirilmez.**
1. Ss + hedef ekran (bileşen + eşlik eden stil dosyası) + `DESIGN.md`'yi oku. **Tutarlılık için** 1-2 kardeş/benzer ekranı da tara (aynı modül ya da aynı tür: liste / detay / form).
1b. **Dal kapsamı: tüm dal + açılır/gizli/iç-içe kabı enumerate et.** Sekmeler, segment-mod, koşullu render'lar, **ve açılışta gizli kaplar**: accordion, collapsible, popover/dropdown/menü içeriği, modal/drawer, açılabilir satır, alt bölüm. Her birini **aç ve içine bak**, ayrı denetle. Her gizli kap ayrı bulguya girer; mümkünse her birinin ss'ini iste.
2. Denetle, **büyük resim → detay** sırasıyla (önce block-frame, sonra piksel):
   1) Amaç + IA / içerik sırası ve öncelik → 2) Layout, hiyerarşi, aksiyon önceliği → 3) Bileşen/kaskad → 4) Token/renk/radius → 5) Tipografi/dil → 6) Durum matrisi + dal kapsamı → 7) A11y → 8) Etkileşim → 9) Tutarlılık (iç + dış).
   Üstte yapısal sorun varsa alt seviye detaya boğulmadan **önce onu işaretle**. Her bulgu: `dosya:satır`, boyut, severity (P0/P1/P2/P3), ihlal edilen DESIGN.md bölümü, tek cümle sorun, somut fix.
3. Emin olmadığın her bulguyu **adversarial doğrula**: satırı gerçekten oku; yanlış pozitifi ele (hex yorumda mı, `var(--*)` mı, translate active-state mi hover mı, native element slot mu gerçek kontrol mü).
4. Puanla ve rapor et.
5. **Kodu iyileştir.** Kullanıcı onaylayınca (net P0/P1 ise doğrudan) bulguları koda uygula; projenin typecheck + lint komutuyla doğrula; tekrar puanla (öncesi → sonrası). Ss öncesi/sonrası kıyas mümkünse yap.

## Boyutlar

Her boyutun kuralı DESIGN.md'nin ilgili bölümünden gelir; aşağıdaki liste **nereye bakılacağını** söyler, kuralı değil.

1. **Token/renk**: hardcoded marka hex / sabit radius, emekli token, marka değerinin tema dosyası dışında olması.
2. **i18n**: hardcoded string (JSX/placeholder/aria-label/alt), diller arası drift, smart quote (U+2019), em dash (U+2014).
3. **Bileşen**: projenin bileşen kaskadı dışına çıkan native `<input>/<button>/<select>/<textarea>` ya da ham inline `<svg>`; tek seferlik ekran-içi custom.
   - **Kanon parite:** DESIGN.md'de kanonik bileşen kaydı varsa ekranın her bileşenini onunla karşılaştır. Legacy kullanım = P1, sapılan kanonu yaz. Kayıtta olmayan bir çift desen (aynı işi yapan iki bileşen) = P2 süreç bulgusu.
4. **Layout + boşluk + aksiyon hiyerarşisi**:
   - Kutu-kutu **eşit** gap (grup içi < grup arası); ölçek dışı px; buton iç padding simetrik + yatay > dikey + aynı tür aynı; kenar inset sabit, kenara yapışan öğe yok; görünmez-grid hizalama; dikey ritim tutarlı. **Çoğu ss'ten ölçülür.**
   - **Buton önceliği:** görünüm başına tek primary; ikincil sönük, yıkıcı soft; iki primary yan yana = bulgu.
5. **Elevation/motion**: hover'da `transform/translate/scale` (active `translate-y-px` hariç); geçiş süresi 120-200 ms dışı.
6. **A11y** (WCAG 2.2 AA + WAI-ARIA APG): kontrast metin ≥ 4.5:1, büyük metin/UI ≥ 3:1, light + dark; klavye ile her etkileşim, mantıklı Tab sırası, `focus-visible` ezilmemiş; karmaşık widget APG rol + ok tuşu; hata `aria-invalid` + `aria-describedby`; her input görünür label; ikon-buton `aria-label`; dekoratif ikon `aria-hidden`; anlam yalnız ikon/renkle taşınmaz; dokunma hedefi ≥ 44 px; `prefers-reduced-motion`; başlık sırası atlamaz.
7. **Durum matrisi**: empty / loading (skeleton) / error tanımlı mı; liste/tablo ekranında mobil kart var mı.
8. **Dil + IA**: yerel glif/casing, aglütinasyon taşma/kesme, tabular rakam; navigasyon derinliği ≤ 3, findability, tutarlı aksiyon yerleşimi. **İçerik sırası:** ekrandaki her alan mantıksal sıra + öncelikte mi (girdi → türetilen, ilişkili bilgi tek blok, tek varlık bölünmemiş). Yanlış sıra = doğruluk + güven bulgusu.
9. **Tutarlılık**, iki eksen:
   - **İç (sayfa içi):** aynı öğe aynı görünür/davranır: spacing ritmi, buton stil/boyut, başlık ölçeği, ikon seti, section düzeni.
   - **Dış (ekranlar arası):** kardeş ekranlarla aynı desen: başlık şeridi, aksiyon yerleşimi, section kurgusu, terminoloji, token, **aynı desen için aynı bileşen**. Bulguda hangi kardeş ekrandan saptığını yaz.

## Puanlama

- Başlangıç **100**. Her doğrulanmış bulgu düşer: **P0 −20 · P1 −10 · P2 −4 · P3 −1**. Taban 0.
- Boyut başına durum: ✅ temiz · ⚠️ minor (yalnız P3) · ❌ major (P0/P1 var).
- **Verdict:** _ship-ready_ = puan ≥ 90 VE P0/P1 yok. Aksi hâlde _düzeltme gerek_.

## Çıktı formatı

```
Tasarım uyumluluk: <ekran> - <puan>/100 (<verdict>)

Boyut skorları:
  Token/renk        ✅ / ⚠️ / ❌
  i18n              ...
  Bileşen           ...
  Layout            ...
  Elevation/motion  ...
  A11y              ...
  Durum matrisi     ...
  Dil + IA          ...
  Tutarlılık        ...  (iç + dış; sapılan kardeş ekranı belirt)

Bulgular (severity sırası, en ağır önce):
  [P1] dosya:satır - <sorun> → <fix>  (DESIGN.md <bölüm>)
  [P2] ...
```

Yalnız DESIGN.md kurallarını uygula. Bulgu yoksa boyut ✅ ve puan 100.

## Multi-agent modu (`--multi`)

Büyük/kritik ekran ya da toplu denetim için `/tasarim-kontrol <ekran> --multi`: Workflow ile paralel fan-out. Bayraksız çağrı tek ajan, aynı akış seri.

| Rol | Model | Effort |
|---|---|---|
| Orkestrasyon (deterministik script) | ucuz | low |
| Keşif (dal/dosya/kardeş enumerate) | küçük | low |
| Mekanik boyutlar (hex/native/i18n/radius/durum) | küçük | medium |
| Muhakeme boyutlar (IA/hiyerarşi/aksiyon/tutarlılık/a11y-APG) | büyük | high |
| Görsel (ss) | büyük | high |
| Adversarial doğrulama | büyük | **üreticiden bir kademe üstte** |
| Kod-fix + skor sentezi | büyük | high / medium |

Bağlayıcı: doğrulayıcı asla ucuzlatılmaz, zayıf doğrulayıcı = rubber-stamp, tüm puanın güvenilirliği gider. Mekanik boyutlar küçük model ama `medium` (i18n çift taraf + kaskad CSS çok dosyalı bağlam ister). Kod-fix projenin branch/commit kuralına uyar.

## Kardeş skill'ler

| Skill | Ne zaman |
|---|---|
| `/yeni-ozellik` | Kod yazmadan önce |
| `/modul-kontrol` | Yazılmış modülde eksik senaryo avı |
| `/tasarim-kontrol` | Ekran bitince (bu skill) |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi |
| `/giray` | Hangisini kullanacağını bilmiyorsan |
