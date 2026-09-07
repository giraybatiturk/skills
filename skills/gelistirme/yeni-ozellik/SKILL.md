---
name: yeni-ozellik
description: Yeni özelliğe kod yazmadan ÖNCE çalışır. Niyeti keşfeder, mevcut durumu ölçer, sekiz sınıfta senaryo ve beş başlığı onaya sunar. Onay gelmeden dosya açılmaz.
disable-model-invocation: true
---

# /yeni-ozellik

Argüman: özellik/modül adı ya da tek cümlelik istek (ör. `mesajlaşmaya medya desteği`).

**Bu skill çalışmadan yeni özellik için ekran/uç dosyası açılmaz.** Beş başlık kullanıcıya gösterilip onay alınmadan dosya açılmaz. Kullanıcı "hızlı olsun" dese bile kısaltılır, atlanmaz.

## Neden

Doğrudan koda başlandığında ön yüz biter ama arka yüz eksik kalır, sözleşme tutmaz, hata canlıda çıkar. Ölçülmüş vaka: bir mesajlaşma modülünde 21 senaryonun 10'u eksik çıktı ve neredeyse hepsini kullanıcı canlıda buldu. Okunmamış rozeti hiç düşmüyordu, sekiz yetki aksiyonundan yalnız biri uygulanmıştı, hata metni ham backend kodu gösteriyordu. Hiçbiri mutlu yolda görünmüyordu.

Bu skill'in işi, o listeyi **kod yazılmadan önce** çıkarmak.

## Akış

### 0. Niyeti keşfet

`superpowers:brainstorming` kuruluysa onu çalıştır; değilse aynı soruları kendin sor. Kim için, hangi problem, başarı neye benziyor, kapsam dışı ne. Kullanıcı "zaten belli" dese bile en az üç soru sor. Belirsiz kalan her şey sonradan yeniden yapılan iş olur.

### 1. Analiz: bugün ne var

**Ölç, tahmin etme.** `/modul-kontrol` envanter yaklaşımını uygula: mevcut uçlar, yetki aksiyonları, hata kodları, ekranlar, durum kapsamı. Ölçemediğin şeyi (backend sözleşmesi, üçüncü parti davranışı) raporda **"ölçemedim"** diye yaz ve kimin doğrulayacağını belirt.

Çıktı: "bugün şu var, şu yok, şu yarım."

### 2. User story'ler

Her senaryo şu biçimde:

```
<Rol> olarak <eylem> istiyorum ki <fayda>.

Kabul   Verildiğinde <ön koşul>, yapıldığında <eylem>, o zaman <beklenen sonuç>.
```

Kabul ölçütü **ölçülebilir** olmalı: "iyi çalışır" değil, "listede görünür ve sayaç 1 artar".

Yalnız mutlu yolu yazma. Sekiz sınıfın **her biri** için en az bir senaryo:

1. **Yetki**: backend'in tanımladığı her aksiyon ayrı senaryo; yetkisi olmayan kontrolü görmemeli
2. **Durum geçişleri**: kur / boz / yeniden kur; sayaç azalıyor mu, önbellek tazeleniyor mu
3. **Hata yolları**: her hata kodu için metin var mı; bir hata kaç bildirim üretiyor
4. **Boş ve ara haller**: veri yok / yükleniyor / hata / yetkisiz / üçüncü parti bekliyor
5. **Çok kullanıcı**: aynı kaydı iki kişi açarsa; kim yaptı görünüyor mu
6. **Üçüncü parti**: sağlayıcı biçim değiştirirse; jeton ne kadar yaşıyor; sağlayıcının kendi sihirbazının ürettiği kodla bizimki aynı mı
7. **Sözleşme tutarlılığı**: aynı kavram her yerde aynı formatta/adla mı; nullable tutarlı mı
8. **Ortam ve dağıtım**: canlıda her müşteriyi etkileyen kırılganlık var mı; sır/provizyon kim yapacak

### 3. Arka yüz kapsamı

- Hangi uçlar: **var olan mı, yeni mi**
- Hangi alanlar: tip, nullable mı
- **Geriye uyum, iki yönlü:**
  - Alan **eklenirse** eski istemci kırılır mı? Zorunlu alan eklemek kırar, opsiyonel eklemek kırmaz.
  - Alan **gelmezse** ekran ne yapar? Her yeni opsiyonel alan için varsayılan davranış yazılı olmalı.

  Emsal: bir `approvalStatus` alanı gelmediğinde hesap onaylı sayıldı; backend deploy edilmeden de ekran çalıştı. Bu davranış bilinçli yazıldığı için sorun çıkmadı. Yazılmasaydı alan gelene kadar bütün hesaplar "onay bekliyor" görünecekti.
- **İzin aksiyonları**: hangileri seed'lenecek, hangisi hangi kontrolü açacak
- **Hata kodları**: uç ne dönebilir, her biri i18n sözlüğüne girecek mi
- Kim yapacak, ne zaman

### 4. Ön yüz kapsamı

- Ekranlar ve rotalar
- Durum matrisi: boş / yükleniyor / hata / yetkisiz (projenin DESIGN.md'sindeki durum bölümü)
- Metinler: projenin tüm dillerinde, aynı anda
- Varyantlar: proje çok markalı/çok sektörlüyse her varyantta farklı mı
- Mobil: dar ekranda ne oluyor
- Yetki: her kontrol hangi aksiyona bağlı

### 5. Bağlantı

Adres, gövde, başlıklar, CORS, zaman aşımı, gerçek zamanlı kanal, dağıtım kısıtı. İki tarafın nerede buluştuğu.

### 6. Onay kapısı

Beş başlığı kullanıcıya sun. **Onay gelmeden dosya açma.** Onayla birlikte gelen kapsam değişikliklerini yaz, sonra başla.

## Çıktı

Kısa özellikte sohbet içinde tablo yeterli. Modül büyüklüğünde iş için paylaşılabilir bir doküman (Artifact) yayınla; ekibe ve issue tracker'a link gider.

Sonunda üç liste ayrık olsun:

- **Bizde** (ön yüz): sırayla yapılacaklar
- **Arka yüzde**: tek liste hâlinde issue tracker'a taşınacak
- **Ölçemedim**: kimin doğrulayacağı yazılı

## Kardeş skill'ler

| Skill | Ne zaman |
|---|---|
| `/yeni-ozellik` | Kod yazmadan önce (bu skill) |
| `/modul-kontrol` | Yazılmış modülde eksik senaryo avı |
| `/tasarim-kontrol` | Ekran bitince, görsel + DESIGN denetimi |
| `/perf-kontrol` | Bağımlılık eklenince, yayın öncesi |
| `/giray` | Hangisini kullanacağını bilmiyorsan |
