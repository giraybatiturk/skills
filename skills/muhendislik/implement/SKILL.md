---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

> **Local workflow rules:**
> - Çıktı ve kullanıcıyla konuşma Türkçe; kod, komut, dosya adı ve teknik terim olduğu gibi.
> - Ölç, tahmin etme: depodan ve çalışan sistemden kanıt; ölçemediğini "ölçemedim" diye yaz.
> - Em dash yok, başlıklarda sentence case, tam diakritik.
> - Yeni özellik kod yazmadan önce `/yeni-ozellik` beş başlık kapısından geçer; bu skill o kapının yerine geçmez.
> - Issue tracker ve etiketler `docs/agents/` altından okunur (`/setup`).

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use /code-review to review the work.

Commit your work to the current branch.
