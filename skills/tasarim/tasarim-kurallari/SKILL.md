---
name: tasarim-kurallari
description: UI/arayüz işi yaparken bağlayıcı genel tasarım kuralları (token disiplini, formlar, durumlar, erişilebilirlik, UX yazımı). Herhangi bir ekran, bileşen, form veya görsel işinde yükle.
---

# Tasarım Kuralları (genel)

Bu kurallar herhangi bir projede arayüz/UI işi yaparken bağlayıcıdır. Proje-bağımsızdır.
Bir projenin kendi `DESIGN.md`'si varsa **o önceliklidir**; bu dosya taban kuraldır.

## 0. Temel ilkeler

- **Az ve net.** Her ekranda tek bir asıl iş olsun; gerisi sessize çekilsin.
- **Tutarlılık > yaratıcılık.** Aynı şey her yerde aynı görünür ve aynı davranır.
- **Gerçek kaynağa bağlı kal.** Bileşen/ölçü/renk uydurma; tasarım sisteminden,
  registry'den, dokümandan çek. Bilmiyorsan tahmin etme, sor.
- **Erişilebilirlik opsiyon değil.** Klavye, kontrast, ekran okuyucu baştan düşünülür.

## 1. Tasarım sistemi ve token disiplini

- UI **tasarım sisteminin bileşenlerinden** kurulur (shadcn/Base UI/COSS, MUI,
  projede ne varsa). Elle markup ile buton/input/dialog/card uydurma yok.
- Bir varyasyon lazımsa önce bileşenin **mevcut prop / variant / size**'ıyla çöz.
- Renk, boşluk, radius, gölge, tipografi **semantic token**'lardan gelir
  (`bg-primary`, `text-muted-foreground`, `rounded-md`, `gap-4`...). Ham hex/px
  yazma; token dışına çıkma.
- Layout (grid/flex/boşluk) Tailwind utility'leriyle olur; görsel parçalar
  (kart, alan, buton, rozet, menü) hep bileşen.

## 2. Yeni bileşen protokolü (önce UYAR)

Tasarım sisteminde olmayan bir şey gerekiyorsa **doğrudan yazma, önce dur ve bildir.**
1. **İşaretle:** "Bu sistemde yok" de, ekrana gömmeden önce söyle.
2. **Kaynakta ara:** registry/particles/dokümanda var mı bak; varsa gerçek
   kaynaktan çek.
3. **Kompoze et:** yoksa mevcut primitiflerden birleştirilebilir mi (Popover +
   Command, Field + Input).
4. **Birlikte karar:** hâlâ gerekiyorsa kalıcı bileşen olarak eklemeye birlikte
   karar ver. Tek seferlik, ekran içi custom bileşen yaratma.

## 3. Görsel hiyerarşi ve düzen

- **Ne önce görünmeli?** Asıl aksiyon/bilgi en güçlü; ikincil olanlar zayıf.
  Her şey öne çıkarsa hiçbir şey öne çıkmaz.
- Hiyerarşiyi renkle değil **boyut, ağırlık, kontrast ve boşlukla** kur.
- İlişkili öğeleri **yakınlıkla** grupla; ayrı şeyleri boşlukla ayır. Çizgi/kutu
  eklemeden önce boşlukla çözmeyi dene.
- Görsel sadelik: gereksiz çerçeve, gölge, ayraç, dekorasyon ekleme. Her eleman
  bir işe yaramalı.

## 4. Tipografi

- Sınırlı bir **ölçek** kullan (örn. 12/14/16/20/24...); ara değer uydurma.
- Hiyerarşi: boyut + ağırlık. Uzun metinde satır yüksekliği rahat (~1.5), başlıkta sıkı.
- Satır uzunluğu okunur tut (~60-75 karakter). Her şeyi bold yapma; vurgu seyrek.

## 5. Renk ve kontrast

- Renk paleti token'dan; nötr (gri) tonlar gövdeyi taşır, **primary** aksiyon,
  **accent** vurgu içindir. Marka rengi kimlik içindir, her butona değil.
- Metin/zemin kontrastı **WCAG AA** (normal metin 4.5:1, büyük metin 3:1).
- **Anlamı yalnız renkle taşıma.** Durum/hata renge ek olarak ikon + metinle de anlatılır.
- Açık ve koyu tema ikisi de çalışmalı; renkler token üzerinden iki temada da AA tutmalı.

## 6. Boşluk ve ölçü

- Tutarlı bir **boşluk ölçeği** (4/8px grid) kullan; gelişigüzel px verme.
- İçeriği nefes aldır; sıkışıklık yerine ritim. Eşit ve öngörülebilir aralıklar.
- Dokunma hedefleri en az ~40px; tıklanabilir alanlar yeterince büyük.

## 7. Formlar

### Label
- Her alanın **görünür label'ı** olur; placeholder label yerine geçmez.
- Kısa isim öbeği, sentence case: "E-posta adresi", "Telefon numarası".
- Zorunluluk işareti tutarlı (`*` veya "(zorunlu)"), her formda aynı.

### Placeholder
- **Az kullan**, yalnız format örneği için: `ad@ornek.com`, `5XX XXX XX XX`.
- Talimat veya zorunlu bilgi yazma (odakta kaybolur, erişilemez). Örnek yoksa koyma.

### Yardım metni
- Alanın **altında**, statik, kısa (~20 kelime). Beklenen formatı/nedeni açıklar.

### Doğrulama
- **Inline** ve **alandan çıkışta** (on blur) ya da yazarken; sadece submit'te toplu hata gösterme.
- Hata kalıbı: `[Alan] [spesifik gereklilik]` — "E-posta @ içermeli",
  "Şifre en az 8 karakter", "Gelecek bir tarih seç".
- Suçlayıcı dil yok ("geçersiz", "hatalı"). Çözüm odaklı, spesifik.
- Hata **ikon + metin**, alanın altında; yalnız renkle anlatma.

### Kompozisyon ve aksiyon
- Alanlar sistemin form primitifleriyle kurulur (Field + Label + kontrol +
  Description + Error). Kendi label/error markup'ını yazma.
- Geçersiz/odak/disabled görünümü durum prop'larından (`data-invalid`/`aria-invalid`)
  gelir; elle renk/border verme.
- Birincil aksiyon belirgin buton, ikincil/iptal sönük (ghost/outline).
- Buton metni fiil + nesne: "Kaydet", "Hesabı sil". "Gönder", "Tamam" gibi jenerik yok.
- Yükleme durumunda butonun `loading`/disabled hali; ayrı spinner ekleme.

### Erişilebilirlik
- Label ↔ input bağlı; hata `aria-describedby` ile bağlanır.
- Form tümüyle klavyeyle gezilebilir; `focus-visible` ring korunur.

## 8. İkonlar

- **Tek ikon seti** kullan (genelde `lucide-react`); başka kütüphane karıştırma.
- İkon boyutunu bileşen ayarlar; elle `size-*` ekleme (bileşen dışı tek ikon hariç).
- Dekoratif ikon `aria-hidden`; tıklanabilir ikon görünür label veya `aria-label`.
  Yalnız ikonla anlam taşıma.

## 9. Durumlar ve geri bildirim

- **Boş durum:** kısa başlık + ne yapılacağını söyleyen tek aksiyon. "Veri yok"
  deyip bırakma, çıkış yolu ver.
- **Yükleniyor:** layout'u taklit eden **skeleton** (boş ekran/ortada tek spinner değil);
  satır içi kısa bekleme için spinner.
- **Hata:** alan hatası inline; bölüm/sayfa hatası başlık + "Tekrar dene" aksiyonu,
  suçlayıcı olmayan dil.
- **Toast:** işlem sonucu kısa geçici bildirim ("Kaydedildi", "Bağlantı kopyalandı").
  Kalıcı/uzun bilgi için inline alan kullan, toast değil.

## 10. Metin (UX writing)

- Amaçlı, kısa, konuşma dilinde, net. Cümleler kısa (8-14 kelime).
- Kullanıcı diline yaz, sistem diline değil. Jargon ve teknik terimden kaçın.
- **Em dash (—) kullanma.** Sade noktalama: virgül, nokta, parantez. Zorlama tireli birleşik yok.

## 11. Süreç

- Tasarım/UI denetimi için **`/tasarim-kontrol`** komutu (kurulu skill'leri orkestre
  eder: critique-loop, refactoring-ui, shadcn, ux-writing, görsel doğrulama).
- "Bitti" demeden önce: hedef tasarım sisteminin diline uyuyor mu, token dışına
  çıkılmış mı, form/durum/erişilebilirlik kuralları sağlanmış mı kontrol et.

## 12. Kapsam dışı

- **Marka rengi seçimi** bu dosyada yok; o projeye/ürüne göre token'da tanımlanır.
- Belirli bir estetik (brutalist/minimal/glassmorphism vb.) dayatılmaz; proje
  yönü neyse ona uy. Bu dosya o yönü **iyi uygulamanın** kuralı.
