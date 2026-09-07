# Skills for Real AI Product Leads

Bir AI Product Lead'in her gün kullandığı skill'ler: fikri keskinleştir, kod yazmadan önce kapıdan geçir, spec ve ticket'a böl, test önce yaz, bitince modülü, ekranı ve bundle'ı denetle. Küçük, Türkçe, ölçüme dayalı: tahmin değil envanter, mutlu yol değil sekiz sınıf senaryo.

Mühendislik akışı the upstream workflow'ten (MIT) uyarlandı; ürün kapısı ve denetim skill'leri bu repoya özgü.

## Kurulum

Claude Code, plugin olarak (güncellemeler otomatik gelir):

```
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Codex ve diğer ajanlar, ya da düzenlenebilir kopya isteyenler:

```bash
npx skills@latest add giraybatiturk/skills
```

Kurulumdan sonra repoda bir kez `/setup` çalıştır: issue tracker, triage etiketleri ve domain doküman düzeni.

## Öne çıkanlar

- **`/giray`**: nereden başlayacağını bilmiyorsan. Tüm akışın haritası.
- **`/yeni-ozellik`**: kod yazmadan önce. Niyet, ölçüm, sekiz sınıf senaryo, beş başlık, onay kapısı.
- **`/grill-with-docs`**: fikri röportajla keskinleştir, `CONTEXT.md` ve ADR bırak.
- **`/modul-kontrol`**: yazılmış modülde eksik senaryo avı.
- **`/tasarim-kontrol`**: ekranı DESIGN.md'ye karşı 9 boyutta puanla.
- **`/tdd`**: kırmızı-yeşil-refactor, dilim dilim.

## Skill seti

### Ürün kapısı ve denetim (`skills/gelistirme`, `skills/tasarim`)

| Skill | Ne zaman | Çağıran |
|---|---|---|
| [giray](./skills/gelistirme/giray/SKILL.md) | Hangisini kullanacağını bilmiyorsan | sen |
| [yeni-ozellik](./skills/gelistirme/yeni-ozellik/SKILL.md) | Kod yazmadan önce | sen |
| [modul-kontrol](./skills/gelistirme/modul-kontrol/SKILL.md) | Yazılmış modülde eksik senaryo avı | sen |
| [perf-kontrol](./skills/gelistirme/perf-kontrol/SKILL.md) | Bağımlılık eklenince, yayın öncesi | sen |
| [tasarim-kontrol](./skills/tasarim/tasarim-kontrol/SKILL.md) | Ekran bitince, DESIGN.md denetimi | sen |
| [tasarim-kurallari](./skills/tasarim/tasarim-kurallari/SKILL.md) | Her UI işinde | model |

### Mühendislik akışı (`skills/muhendislik`, the upstream workflow uyarlaması)

| Skill | Ne zaman | Çağıran |
|---|---|---|
| [setup](./skills/muhendislik/setup/SKILL.md) | Repoda bir kez: tracker, etiket, doküman düzeni | sen |
| [grill-with-docs](./skills/muhendislik/grill-with-docs/SKILL.md) | Fikri keskinleştir, repo içinde | sen |
| [grill-me](./skills/muhendislik/grill-me/SKILL.md) | Aynı röportaj, repo yokken | sen |
| [to-spec](./skills/muhendislik/to-spec/SKILL.md) | Sohbeti spec'e çevir | sen |
| [to-tickets](./skills/muhendislik/to-tickets/SKILL.md) | Spec'i bloklama kenarlı ticket'lara böl | sen |
| [implement](./skills/muhendislik/implement/SKILL.md) | Ticket'ı uygula, içinde tdd + code-review | sen |
| [triage](./skills/muhendislik/triage/SKILL.md) | Gelen bug/istek yığınını rollere ayır | sen |
| [grilling](./skills/muhendislik/grilling/SKILL.md) | Röportaj ilkeli, diğerleri bunu çağırır | model |
| [tdd](./skills/muhendislik/tdd/SKILL.md) | Test önce, dilim dilim | model |
| [code-review](./skills/muhendislik/code-review/SKILL.md) | Standart + spec iki eksende diff incelemesi | model |
| [diagnosing-bugs](./skills/muhendislik/diagnosing-bugs/SKILL.md) | Zor bug: önce kırmızı veren döngü, sonra teori | model |
| [prototype](./skills/muhendislik/prototype/SKILL.md) | Tek soruya cevap veren atılabilir kod | model |
| [research](./skills/muhendislik/research/SKILL.md) | Birincil kaynaklardan araştırma, dosyaya | model |

"sen" = `disable-model-invocation: true`, yalnız `/ad` ile çalışır. "model" = konu eşleşince kendiliğinden yüklenir.

## Nereden başlanır

```
fikir      /grill-with-docs        fikri keskinleştir, CONTEXT.md
kapı       /yeni-ozellik           beş başlık, sekiz sınıf senaryo, onay
plan       /to-spec  →  /to-tickets
kod        /implement              içinde /tdd ve /code-review
denetim    /modul-kontrol  →  /tasarim-kontrol  →  /perf-kontrol
bug        /diagnosing-bugs        sonra /modul-kontrol: kardeşi var mı
```

1-3 arası tek bağlam penceresinde kalır; `/to-tickets`'a kadar compact/clear yok. Her `/implement` sıfırdan başlar.

## Proje bağımlılığı

Denetim skill'leri projenin `DESIGN.md` ve `AGENTS.md`/`CLAUDE.md` dosyalarını kural kaynağı sayar; yoksa `tasarim-kurallari` taban olur. Mühendislik skill'leri `docs/agents/` altını okur; `/setup` yazar.

## Değişiklikler

- **0.2.0** (2026-09-07): the upstream workflow'ten 13 skill `skills/muhendislik/` altına alındı, her birine Giray uyarlaması bloğu; `start` yerine `giray`; `setup` → `setup`; MIT lisans.
- **0.1.0** (2026-09-07): ilk set, 6 skill.
