---
name: modul-kontrol
description: Bir özelliği/modülü kullanıcı senaryolarına karşı denetler. Eksik case'leri koddan ve backend sözleşmesinden ÖLÇEREK çıkarır; sekiz sınıfta senaryo, yetki matrisi, öncelik sırası üretir.
disable-model-invocation: true
---

# /modul-kontrol

Argüman: modül/özellik adı (ör. `mesajlaşma`, `randevu`, `tahsilat`). Verilmezse üzerinde çalışılan modülü sor.

**Ne zaman çalıştırılır**

- Bir modüle **ikinci kez** dokunurken (sıfırdan değil, üstüne ekleme)
- "Bu neden çalışmıyor" turları başladığında: bir hata bulununca **aynı sınıftan başka ne var** diye
- **Canlıya çıkmadan önce**: test'te çalışan modül müşteriye gitmeden
- Uzun süre dokunulmamış bir modüle geri dönerken

İki modda çalışır:

- **Önden** (yeni özellik, kod yazmadan): `/yeni-ozellik` beş başlığını üretir, onaya sunar.
- **Sonradan** (yazılmış, çalışan modül): mevcut koddan senaryo envanteri çıkarır, eksikleri işaretler.

## Neden

Doğrudan koda başlandığında **mutlu yol** biter; hata yolları, yetki halleri ve durum geçişleri eksik kalır. Kullanıcı bunları canlıda tek tek bulur ve her biri ayrı bir tur olur.

Ölçülmüş vaka (bir mesajlaşma modülü): 21 senaryonun 10'u eksik, 5'i yarımdı. Eksiklerin çoğunu kullanıcı keşfetti. Okunmamış rozeti hiç düşmüyordu, bağlantı kesilince sayaç doluydu, hata metni ham backend kodu gösteriyordu, sekiz yetki aksiyonundan yalnız biri uygulanmıştı. Hiçbiri mutlu yolda görünmüyor; hepsi ikinci adımda çıkıyor.

## Akış

0. **Ölç, tahmin etme.** Envanterleri çıkar. Ölçemediğin şeyi (backend sözleşmesi, üçüncü parti davranışı) raporda **"ölçemedim"** diye yaz ve kimin doğrulayacağını belirt. Sessizce varsayma.
1. Envanterleri çıkar (uç, yetki, hata kodu, durum).
2. Kontrol listesindeki her sınıfı modüle uygula; her biri için senaryo yaz.
3. Her senaryoyu **rol + eylem + kabul ölçütü** biçiminde yaz, altına **bugün ne oluyor** ve **sahibi** (ön yüz / arka yüz / devops) ekle.
4. Durumla: `çalışıyor` (uçtan uca denendi) · `yarım` (bir taraf hazır, diğeri yok) · `eksik`.
5. Raporla; sıra öner (canlı öncesi kapı olanlar en üstte).
6. Onay alınırsa ön yüz tarafındaki eksikleri uygula; arka yüz tarafındakileri tek liste hâlinde issue tracker'a taşı.

## Envanterler

Projeye göre komutları kendin türet; ilk çalıştırmada bulduğun yolları projenin `AGENTS.md`/`CLAUDE.md`'sine yaz ki sonraki tur grep'lemesin. Şu yedi soruya cevap gerekir:

```bash
# 1. Uçlar: modülün konuştuğu her adres
grep -rnoE "['\"](/?api/)?v[0-9]+/<modül>[a-zA-Z/_-]*['\"]" <api-istemci-dizini> | sort -u

# 2. Yetki aksiyonları: backend NE tanımladı
# Sözleşme dosyasında yoksa admin panelindeki yetki matrisinden oku ve bir regresyon testi yaz.
grep -rn "<MODÜL>_\(MODULE\|ACTION\)\|can(['\"]<modül>" <tip-dizini>

# 3. Ön yüz hangi aksiyonu SORUYOR: (2) ile farkı en sık bulunan eksik
# Ekran + rota + uygulama kökü (rota kapısı) üçünü birden tara; biri atlanırsa
# "kapı var ama ekran içinde kontrol yok" görünmez.
grep -rn "can(" <ekran-dizini>/<modül> <rota-dizini> <App-dosyası> | grep -i <modül>

# 4. Hata kodu kapsamı: modülün kodları sözlükte var mı
grep -n "<MODÜL>_" <i18n-sözlük-dosyası>

# 5. Hata kaç yerden gösteriliyor: çift bildirim avı
grep -rn "toast.*error\|onError" <ekran-dizini>/<modül>

# 6. Ham hata metni sızıntısı (repo geneli sınıf hatası)
grep -rn "error(\(hata\|err\|error\)\.message" <kaynak-dizini> | wc -l

# 7. Durum matrisi kapsamı
grep -c "Skeleton\|Empty\|isError\|retry" <ekran-dizini>/<modül>/*.tsx
```

## Kontrol listesi, sınıf sınıf

Her sınıf için en az bir senaryo yaz. Sınıfı atlamak, o sınıfın hatasını canlıya bırakmaktır.

### 1. Yetki

- Backend'in tanımladığı **her aksiyon** için ayrı senaryo: o yetkisi olmayan kullanıcı ilgili kontrolü **görmemeli**.
- Yalnız modül kapısını sormak yetmez; `send`, `delete`, `add` gibi aksiyonlar ekranın İÇİNDE ayrı ayrı sorulmalı.
- Kontrol sorusu: "yetkisi olmayan biri bu butona bassa ne olur?" Cevap "backend 403 döner" ise buton hiç görünmemeliydi.

### 2. Durum geçişleri (yalnız ilk hal değil)

- Kur → boz → yeniden kur. Her adımda **panelin geri kalanı** ne gösteriyor?
- Sayaç ve rozetler: artıyor mu, **azalıyor mu**, sıfırlanıyor mu? Yalnız artan sayaç bir hatadır.
- Oturum kapat/aç, hesap/şirket değiştir, yetki değiştir: önbellek eski veriyi tutuyor mu?
- İlgili mutasyonlar bağlı sorguları invalidate ediyor mu? Bir kayıt silindiğinde onu sayan her yer tazelenmeli.

### 3. Hata yolları

- Backend'in dönebileceği **her hata kodu** için: sözlükte karşılığı var mı, yoksa ham kod ekrana düşer.
- Bir hata **kaç bildirim** üretiyor? Genel yakalayıcı + ekranın kendi bildirimi = çift.
- Ham `err.message` gösterilmiyor: backend `message` alanı genelde kullanıcı metni değil **kod** taşır.
- Ağ kesik, zaman aşımı, sunucu 500: bunlarda hangi metin çıkıyor?

### 4. Boş ve ara haller

- Hiç veri yok · yükleniyor · hata · yetkisiz · üçüncü parti onayı bekliyor · üçüncü parti reddetti.
- Aynı ekranda **kaç boş durum mesajı** aynı anda görünüyor? Birden fazlaysa kullanıcı hangisine bakacağını seçmek zorunda kalır.

### 5. Çok kullanıcı ve çok kayıt

- İki kullanıcı aynı kaydı aynı anda açarsa/değiştirirse?
- Kim yaptı bilgisi görünüyor mu? Çok kişili hesapta "bu işlemi kim yaptı" sorusunun cevabı olmalı.
- Binlerce kayıtta arama tek başına yetiyor mu, süzgeç ve toplam gerekiyor mu?

### 6. Üçüncü parti bağımlılığı (varsa)

- Sağlayıcı tarafında onay/inceleme durumu var mı, kullanıcı bunu görüyor mu?
- Sağlayıcı veri biçimini değiştirirse ne olur? Alan adı değişimi sessizce veri düşürebilir.
- Bizim tarafımızda saklanan yetki/jeton ne kadar yaşıyor, yenileniyor mu, koparsa kullanıcı nasıl anlıyor?
- Sunucu yeniden başladığında bağlantı hayatta kalıyor mu?

**Kurulum doğrulaması: sağlayıcının kendi çıktısıyla karşılaştır.** Çoğu sağlayıcının konsolunda "senin uygulaman için" kod üreten bir sihirbaz vardır (Meta Embedded Signup Builder, Stripe entegrasyon örnekleri). Bizim kodu **onun ürettiğiyle satır satır** karşılaştır: sürüm alanları aynı mı (akış, SDK, API sürümü ayrı ayrı olabilir), zorunlu parametrelerden eksik var mı, konsoldaki kontrol listesi yeşil mi.

Gerekçe: bir Embedded Signup son adımda beyaz kalıyordu. Kod doğru görünüyordu, ağ istekleri temizdi, sağlayıcı hata vermiyordu. Sebep `extras` içinde **akış sürümünün hiç olmamasıydı**; sağlayıcı sürüm verilmeyince eski akışa düşüyor ve o akış geri dönmüyordu. Bulunma yolu: sağlayıcının kendi builder'ının ürettiği snippet ile bizimkini yan yana koymak. Bir gün kaybettirdi.

### 7. Sözleşme tutarlılığı

Aynı kavram her yerde aynı biçimde mi geliyor:

- **Aynı tip alanlar aynı formatta mı?** Tarih alanlarının bazısı `Z` sonekli bazısı soneksiz olabilir; para bazı yerde kuruş bazı yerde lira; telefon bazı yerde `+90` ile bazı yerde olmadan.
- **Aynı kavram aynı adla mı?** `customerUuid` / `customerId` / `contactUuid` üçü aynı şeyse biri seçilir.
- **Nullable tutarlı mı?** Bir uçta zorunlu, diğerinde opsiyonel dönen alan ön yüzde tip yalanına dönüşür.
- **Liste ile detay aynı şeyi mi söylüyor?** Liste satırındaki değer ile detaydaki değer aynı kaynaktan mı geliyor.

Gerekçe: bir gelen kutusu aynı mesajı listede `20:06`, balonda `23:06` gösteriyordu. İki yer de **aynı fonksiyonu aynı parametreyle** çağırıyordu; fark girdideydi. `lastMessageAt` `Z` soneki olmadan, `sentAt` `Z` ile geliyordu. Tek DTO, iki farklı serileşme. Hiçbir görsel denetim bunu yakalamaz, yalnız iki değeri yan yana koymak yakalar.

### 8. Ortam ve dağıtım

- Bu özellik canlıya çıkarsa **her müşteriyi** etkileyen bir kırılganlık var mı? Varsa canlı öncesi kapı olarak işaretle.
- Ortam değişkeni, sır, altyapı provizyonu gerekiyor mu; kim yapacak?

## Çıktı biçimi

Her senaryo şu üç parçayı taşır:

```
[ID] Başlık                                    [çalışıyor | yarım | eksik]

<Rol> olarak <eylem> istiyorum ki <fayda>.

Kabul   Ölçülebilir kabul ölçütü.
Bugün   Gerçekte ne oluyor; ölçüme dayalı, tahmin değil.
Sahibi  ön yüz / arka yüz / devops
```

Sonunda:

- **Sayı özeti** (çalışıyor / yarım / eksik).
- **Yetki matrisi**: backend aksiyonları × ön yüz soruyor mu × bugünkü sonuç.
- **Sıra**: canlı öncesi kapılar önce, sonra günlük kullanımı eksik bırakanlar, en son sonraki tur.

Rapor uzunsa paylaşılabilir doküman (Artifact) olarak yayınla; issue tracker'a link gider.

## Kardeş skill'ler

| Skill | Ne zaman |
|---|---|
| `/yeni-ozellik` | Kod yazmadan önce |
| `/modul-kontrol` | Yazılmış modülde eksik senaryo avı (bu skill) |
| `/tasarim-kontrol` | Ekran bitince, görsel + DESIGN denetimi |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi |
| `/giray` | Hangisini kullanacağını bilmiyorsan |
