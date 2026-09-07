# Skills for Real AI Product Leads

Bir AI Product Lead'in her projede kullandığı skill'ler: ürün kararı, kod ve tasarım tek akışta. Küçük, Türkçe, ölçüme dayalı: tahmin değil envanter, mutlu yol değil sekiz sınıf senaryo.

## Kurulum

Claude Code, plugin olarak (güncellemeler otomatik gelir):

```
/plugin marketplace add giraybatiturk/skills
/plugin install giraybatiturk-skills@giraybatiturk
```

Diğer ajanlar ya da düzenlenebilir kopya isteyenler:

```bash
npx skills@latest add giraybatiturk/skills
```

## Skill'ler

| Skill | Ne zaman | Çağıran |
|---|---|---|
| [giray](./skills/gelistirme/giray/SKILL.md) | Hangisini kullanacağını bilmiyorsan | sen |
| [yeni-ozellik](./skills/gelistirme/yeni-ozellik/SKILL.md) | Kod yazmadan önce | sen |
| [modul-kontrol](./skills/gelistirme/modul-kontrol/SKILL.md) | Yazılmış modülde eksik senaryo avı | sen |
| [tasarim-kontrol](./skills/tasarim/tasarim-kontrol/SKILL.md) | Ekran bitince, DESIGN.md denetimi | sen |
| [perf-kontrol](./skills/gelistirme/perf-kontrol/SKILL.md) | Bağımlılık eklenince, yayın öncesi | sen |
| [tasarim-kurallari](./skills/tasarim/tasarim-kurallari/SKILL.md) | Her UI işinde | model |

"sen" = `disable-model-invocation: true`, yalnız `/ad` ile çalışır. "model" = konu eşleşince kendiliğinden yüklenir.

## Proje bağımlılığı

Denetim skill'leri projenin kendi `DESIGN.md` ve `AGENTS.md`/`CLAUDE.md` dosyalarını kural kaynağı sayar. Yoksa `tasarim-kurallari` taban olarak devreye girer.
