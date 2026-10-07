# WidgetFix

[English](README.md) | **O'zbekcha** | [Русский](README.ru.md)

Flutter ilovangizning debug build'idagi istalgan widget'ni bosib turing, nima noto'g'ri ekanini yozing va Return tugmasini bosing. Hisobot loyihangizda allaqachon ishlab turgan Claude Code sessiyasiga tushadi: widget, uni yaratgan Dart kodi qatori, skrinshot va sizning so'zlaringiz. Claude kodni tuzatadi va ilovani hot reload qiladi, ilovadagi banner esa tuzatishni navbatga tushganidan to ekranda paydo bo'lguncha kuzatib boradi.

![Simulyatorda widget'larni bosib turish terminaldagi Claude Code'ga hisobot yuboradi: siljib qolgan tugma, yumaloqlanmagan burchaklar, kesilib qolgan ism va qizil rangdagi daromad summasi, har birini Claude tuzatadi va hot reload qiladi](docs/demo.gif)

[Demoni to'liq sifatda ko'ring (MP4, 70 s)](docs/demo.mp4). U jonli yozib olingan: mod o'rnatilgan Claude Code sessiyasi hisobotlar asosida Tally'dagi ataylab qo'yilgan to'rtta xatoni tuzatdi. Faqat kutish joylari tezlashtirilgan.

WidgetFix — bu iOS simulyatoridagi SwiftUI ilovalari uchun xuddi shu ishni bajaradigan [FixKit](https://github.com/ostiums/fixkit) loyihasining Flutter'ga ko'chirilgan versiyasi.

WidgetFix ikki qismdan iborat:

- Claude Code uchun **widget-fix mod** hisobotlarni qabul qiladi;
- **widget_fix Dart paketi** ularni debug build'dan yuboradi. Release va profile build'larda u kompilyatsiya paytida butunlay olib tashlanadi.

## Talablar

- Claude Code 2.1.287 yoki undan yangisi.
- Node.js 18.2 yoki undan yangisi; mod'ning receiver'i shunda ishlaydi.
- Flutter 3.32 yoki undan yangisi. WidgetFix iOS simulyatorida, Android emulyatorida, desktop ilovada va Flutter web'da, shuningdek receiver'ga ulana oladigan telefonda ishlaydi ([Qurilmalar](#qurilmalar) bo'limiga qarang).
- Boshqa hech narsa kerak emas. iOS versiyasiga simulyatorning accessibility daraxtini o'qish uchun AXe kerak edi; Flutter debug build esa har bir widget qaysi qatorda yaratilganini biladi, shuning uchun ilova buni receiver'ga o'zi aytadi.

## O'rnatish

### 1. Mod

```bash
claude plugin marketplace add ushodmonov/widget_fix
claude plugin install widget-fix@widget-fix
```

Shundan so'ng mod har bir Claude Code sessiyasida yuklanadi, lekin hisobotlarni faqat `pubspec.yaml`'i `widget_fix`'ga bog'liq bo'lgan Flutter loyihasida boshlangan sessiya qabul qiladi: sessiya boshlanganda u o'z receiver'ini `127.0.0.1:4747` manzilida ishga tushiradi, sessiya tugaganda esa uni to'xtatadi. Boshqa papkalardagi sessiyalar hisobotlarga tegmaydi.

### 2. Paket

```yaml
dependencies:
  widget_fix:
    git:
      url: https://github.com/ushodmonov/widget_fix
      path: packages/widget_fix
```

Bu dev dependency emas, oddiy dependency: ilova uni import qiladi. Release build'da undan kompilyator olib tashlaydigan bir nechta `kDebugMode` tekshiruvidan boshqa hech narsa qolmaydi.

### 3. Ilovada bitta qator

```dart
import 'package:widget_fix/widget_fix.dart';
import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: WidgetFix.builder,
      home: const HomePage(),
    );
  }
}
```

Butun integratsiya shu. `CupertinoApp` va `WidgetsApp` ham xuddi shu `builder` parametrini qabul qiladi. Agar ilovada allaqachon builder bo'lsa, u qaytaradigan widget'ni o'rab qo'ying: `builder: (context, child) => WidgetFixHost(child: MyFrame(child: child!))`. Host nima qilishi keyingi bo'limda tushuntirilgan.

### 4. Loyiha papkasi

Mod hisobotlarni `claude` ishga tushirilgan papkadagi `.widget_fix/` papkasiga yozadi, shuning uchun uni Flutter loyihasining ildiz papkasida, ya'ni `pubspec.yaml` turgan papkada ishga tushiring va `.widget_fix/` papkasini `.gitignore` fayliga qo'shing. Claude skrinshotlarni ochishi va ilovani har safar ruxsat so'ramasdan reload qilishi uchun loyihaning Claude Code sozlamalarida ikkalasiga ham ruxsat bering:

```json
{
  "permissions": {
    "allow": [
      "Read(./.widget_fix/**)",
      "Bash(pkill -USR1 -F .widget_fix/flutter.pid)",
      "Bash(pkill -USR2 -F .widget_fix/flutter.pid)"
    ]
  }
}
```

### 5. Ilovani Claude reload qila oladigan tarzda ishga tushiring

```bash
flutter run --pid-file .widget_fix/flutter.pid
```

`flutter run` `SIGUSR1` signalini olganda hot reload, `SIGUSR2` signalini olganda esa hot restart qiladi. Agar pid fayl `.widget_fix/` papkasida bo'lsa, Claude tuzatishni yozib bo'lgach ilovani o'zi reload qiladi: `pkill -USR1 -F .widget_fix/flutter.pid`. Bu bitta oddiy buyruq, shuning uchun yuqoridagi ruxsat qoidasi uni qamrab oladi; `kill -USR1 $(cat …)` esa har safar ruxsat so'raydi, chunki Claude Code ichma-ich joylashgan buyruqni u ishga tushishidan oldin tekshira olmaydi. Agar buning o'rniga sessiyaga [Dart MCP serveri](https://docs.flutter.dev/ai/mcp-server) ulangan bo'lsa, Claude uning `hot_reload` tool'idan foydalanadi. Ikkalasi ham bo'lmasa, Claude o'zgarish uchun hot reload kerakligini aytadi va siz `r` tugmasini bosasiz.

## 0.1 dan yangilash

0.1 versiyada har bir Claude Code sessiyasi o'z receiver'ini ishga tushirardi va eng yangi sessiya 4747-portni o'ziga olardi, shuning uchun ilovaning hisobotlari eng oxirgi ochilgan sessiyaga ketardi. 0.2 dan boshlab hisobotlarni faqat WidgetFix loyihasidagi sessiya qabul qiladi va ularni birinchi sessiya o'zida saqlab qoladi ([Ishlatish](#ishlatish) bo'limiga qarang). Yangilash uchun:

1. Modni yangilang:

   ```bash
   claude plugin marketplace update widget-fix
   claude plugin update widget-fix@widget-fix
   ```

2. Ishlab turgan barcha `claude` sessiyalarini yoping. Hali 0.1 da qolgan sessiya, 0.1 doim qilganidek, portni yangisidan tortib oladi. Yopilgan sessiyalardan qolgan receiver'lar bir soniya ichida o'zi to'xtaydi.
3. `claude`'ni Flutter loyihasining ildizida, `pubspec.yaml`'ida `widget_fix` ko'rsatilgan papkada qaytadan ishga tushiring. 0.1 hisobotlarni istalgan papkada qabul qilardi; 0.2 boshqa joyda ularga tegmaydi.

Ilova tomonida hech narsa o'zgarmaydi: paket, `WidgetFix.builder`, `flutter run --pid-file .widget_fix/flutter.pid`, `.widget_fix/` va ruxsatlar avvalgidek qoladi, ilovaga `flutter pub upgrade` ham, qayta ishga tushirish ham kerak emas.

## Nega `WidgetFix.builder` ilovaning builder'iga qo'yiladi

Host ishga tushmaguncha paket hech narsa qilmaydi. `MaterialApp.builder` uni navigator'dan yuqoriga joylashtiradi, shuning uchun u har bir route, dialog va sheet'ni qamrab oladi. U beshta ishni bajaradi:

- **Bosib turish.** U ilovaning o'z gesture'lari bilan yonma-yon, ilova atrofidagi xom pointer event'larini tinglaydi: tugmalar, ro'yxatlar va scroll view'lar ishlashda davom etadi. Bosish yarim soniya qimirlamay tursa, u WidgetFix'ga o'tadi va WidgetFix bu pointer'ni boshqa hamma uchun bekor qiladi, shu bois barmoq ostidagi tugma ham bunga javob bermaydi.
- **Qidiruv.** U nuqtani hit test qiladi va barmoq ostidagi widget'dan yuqoriga qarab yuradi. Har bir `flutter run` debug build'ida yoqilgan Flutter'ning widget yaratilishini kuzatish mexanizmi (widget creation tracking) har bir widget'ni ilovaning o'z kodidagi qaysi qator yaratganini aytadi: bosilgan `Text`, u turgan UI qatori va shu qatorni joylashtirgan boshqa fayldagi widget. Flutter'dan, pub cache'dan va WidgetFix'dan kelgan widget'lar o'tkazib yuboriladi.
- **Izoh oynasi.** U xiralashtirilgan ekranni chizadi: bosilgan widget yoritilgan, izoh maydoni esa klaviatura ustida turadi. Agar klaviatura widget'ni yopib qo'yadigan bo'lsa, u ilovani yuqoriga suradi. Izoh oynasi ochiq turganda ilova avvalgi ekran o'lchamini saqlab qoladi, shuning uchun klaviatura yoritish ostidagi ilovani qaytadan layout qilmaydi.
- **Banner'lar.** U ekranning yuqori qismida hisobot jarayonini ko'rsatadi: yuborildi, navbatda, tuzatilmoqda, reload qilinmoqda, tuzatildi.
- **Reload signali.** Har bir ishga tushishda va har bir hot reload'da u receiver'ga ilova kodi yangilanganini xabar qiladi. Claude hisobot ustida ishlayotgan paytdagi reload mod'ga tuzatish ekranga chiqqanini bildiradi: Claude `flutter run` jarayoniga signal yuborganmi, Dart MCP serveridan foydalanganmi yoki `r` tugmasini o'zingiz bosganmisiz, farqi yo'q. Hot reload ilova holatini (state) saqlaydi, shuning uchun siz hisobot yuborgan ekran ko'rinishda qoladi.

Release yoki profile build'da `WidgetFix.builder` ilovani o'zgarishsiz qaytaradi, `kDebugMode` konstanta bo'lgani uchun esa kompilyator WidgetFix'ning qolgan qismini ham u bilan birga olib tashlaydi. `scripts/test.sh` Tally'ning release build'ida undan hech narsa qolmaganini tekshiradi.

## `Fixable` bilan ishlash

Hech narsani belgilash shart emas. Belgilar bo'lmasa, hisobotda barmoq ostidagi widget va uni yaratgan qator ko'rsatiladi:

```
Income should be green

[fix r1] Text "+€4,650.00" · lib/features/home/transaction_row.dart:50 · in TransactionRow at lib/features/activity/activity_view.dart:93 · near "Salary, September", "Northwind GmbH" · Activity screen · .widget_fix/reports/r1.png
```

`in … at` — uni o'rab turgan, boshqa fayldagi eng yaqin widget: umumiy (shared) widget uchun bu u ishlatilgan joy. Agar widget hisobotlari nom bilan kelishini va barmoq ostidagi matn emas, balki konteyner yoritilishini istasangiz, widget'ni `.fixable` bilan belgilang:

```dart
class WalletCardView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(card.number).fixable('card.number'),
        Text(card.holder).fixable('card.holderName'),
      ],
    ).fixable('home.walletCard');
  }
}
```

`Fixable('card.number', child: Text(card.number))` — xuddi shu belgining uzunroq yozilishi. Belgi nimalarni o'zgartiradi:

- **Hisobot nom bilan boshlanadi.** Undagi qator belgi o'rab turgan widget'ni yaratadigan qatordir, shuning uchun Claude o'qishni shu yerdan boshlaydi:

  ```
  [fix r2] card.holderName · lib/features/home/wallet_card_view.dart:43 · Text "Vladimir Berest…" · .widget_fix/reports/r2.png
  ```

- **Izoh oynasi belgining ramkasini yoritadi**, child'lari orasidagi bo'shliqlar bilan birga, hamda unga nom va fayl ko'rsatilgan yorliq qo'yadi. Skrinshotda shu ramka chiziq bilan ajratib ko'rsatiladi. Belgi bo'lmasa, bosilgan widget yoritiladi, faqat u fon kabi ekranning katta qismini egallagan bo'lsa, bunday qilinmaydi; u holda barmoq atrofida halqa paydo bo'ladi.
- **Ichma-ich belgilardan eng ichkisi tanlanadi.** Yuqoridagi misolda karta egasining ismi bosilsa, hisobotda `card.holderName` bo'ladi, kartaning boshqa joyi bosilsa, `home.walletCard`.

Belgini Claude kodini ochishini istagan widget'ga qo'ying: imlo xatosi yoki rang uchun `Text` widget'ining o'ziga, oraliqlar yoki layout uchun konteynerga. Nom faqat sizga tushunarli bo'lsa yetarli; unda ma'lumot ham bo'lishi mumkin, masalan, `.fixable('transaction.amount.${transaction.merchant}')`. Release build'da belgi widget'ni o'zgarishsiz qaytaradi.

`.fixScreen('Home')` yoki `FixScreen('Home', child: ...)` ekranga nom beradi. Hisobot bosilgan widget'ni o'rab turgan eng ichki ekran nomini oladi, shuning uchun `IndexedStack` yoki navigator ishlatilganda har bir ekran o'z nomiga ega bo'lishi mumkin. Belgi bo'lmasa, nom hisobotga `Home screen` ko'rinishida qo'shiladi.

## Ishlatish

1. Loyiha papkasida `claude` buyrug'ini ishga tushiring. Fix queue paneli kengligi 144 ustun yoki undan katta terminalda ochiladi; `/fix-queue` uni istalgan kenglikda ochadi. Agar loyiha hisobotlarini boshqa sessiya allaqachon qabul qilayotgan bo'lsa, bu sessiya kutish holatida qoladi va buni aytadi; `/fix-take` hisobotlarni shu sessiyaga o'tkazadi.
2. Ilovani debug build'da ishga tushiring: `flutter run --pid-file .widget_fix/flutter.pid`.
3. Ilovadagi widget'ni bosib turing, nima noto'g'ri ekanini yozing va Return tugmasini bosing. Escape tugmasi yoki xiralashgan ekranga bosish izoh oynasini yopadi.

Panel va ilovadagi banner `queued`, `fixing`, `reloading` va `live` holatlaridan o'tadi. Claude hisobot ustida ishlayotganda ilova reload qilinsa, hisobot live holatiga o'tadi va Claude ishni javob bilan yakunlasa ham live bo'lib qoladi. Claude bitta hisobot ustida ishlayotganda yuborilgan hisobotlar navbatda kutib turadi.

## Qurilmalar

Ilova receiver'ni `127.0.0.1:4747` manzilidan, Android'da esa `10.0.2.2:4747` manzilidan ham qidiradi: emulyator o'zi ishlayotgan kompyuterni shu manzil bilan ataydi.

| Ilova qayerda ishlaydi | Unga nima kerak |
| --- | --- |
| iOS simulyatori, Android emulyatori, Flutter web | hech narsa |
| macOS ilovasi | `macos/Runner/DebugProfile.entitlements` faylida `com.apple.security.network.client` |
| USB orqali ulangan Android telefon | `adb reverse tcp:4747 tcp:4747` |
| bir xil tarmoqdagi istalgan telefon | `claude` ishga tushiriladigan muhitda `WIDGET_FIX_HOST=0.0.0.0` va `flutter run --dart-define=WIDGET_FIX_RECEIVER=http://<computer's address>:4747` |

`WIDGET_FIX_PORT` portni ikkala tomonda ham o'zgartiradi: receiver uchun muhit o'zgaruvchisi sifatida, ilova uchun esa `--dart-define` sifatida.

Izoh oynasi va banner'lar Material ikonkalaridan foydalanadi; `flutter create` bilan yaratilgan har bir ilova ularni o'z ichiga oladi (`uses-material-design: true`).

## Qanday ishlaydi

```
app (WidgetFix) ──POST /report──▶ receiver (node, 127.0.0.1:4747) ──▶ .widget_fix/reports/<id>.png, <id>.json
      ▲                               │ one JSON line per report
      │ POST /launched, GET /status   ▼
      └── .widget_fix/status.json ◀── the mod: prompt, Fix queue pane, statuses
```

Bosish ishga tushganda ilova nuqtani hit test qiladi, bosilgan widget'dan host'gacha bo'lgan widget'larning yaratilgan joylarini o'qiydi, o'sha UI qatoridagi matnlarni yig'adi va host ostidagi hamma narsaning skrinshotini oladi, izoh oynasini hisobga olmagan holda. Izoh yozilgach, u hisobotni yuboradi. Receiver skrinshotni va butun hisobotni, widget'larning to'liq zanjiri bilan birga, `.widget_fix/reports/<id>.json` sifatida saqlaydi va hisobotni mod'ga uzatadi; mod prompt'ni yuboradi va system prompt'ga `[fix …]` qatorini tushuntiradigan bo'lim qo'shadi. Mod har bir hisobotning holatini `.widget_fix/status.json` fayliga yozadi, ilova esa bu faylni muntazam so'rab turadi (poll qiladi).

Receiver faqat JSON qabul qiladi va `localhost` orqali berilgan sahifalardan boshqa veb-sahifalardan kelgan so'rovlarni rad etadi, shuning uchun brauzeringizda ochiq turgan sayt sessiyaga prompt yoza olmaydi.

Bir vaqtning o'zida faqat bitta sessiya hisobot qabul qiladi va ularni o'zida saqlab qoladi: keyinroq boshlangan sessiya 4747-port band ekanini ko'radi va kutish holatida qoladi, shuning uchun bir loyihada qo'shimcha savol uchun ochilgan ikkinchi `claude` ilovaning hisobotlarini ilib olmaydi. O'sha sessiyada `/fix-take` hisobotlarni unga o'tkazadi, birinchi sessiyaning paneli esa ular qayerga ketganini ko'rsatadi. Portni ushlab turgan sessiyada modni qayta yuklash portni o'sha sessiyada qoldiradi.

## Misol: Tally

`tally/` — asl FixKit'dagi SwiftUI hamyon ilovasining Flutter versiyasi, unda xuddi o'sha to'rtta ataylab qo'yilgan UI xatosi bor va u ushbu repozitoriydagi paketni path orqali dependency sifatida ishlatadi.

```bash
git clone https://github.com/ushodmonov/widget_fix && cd widget_fix
./scripts/reset-demo.sh                  # puts the bugs back and runs Tally under flutter run
cd tally && claude --plugin-dir ../mod   # in another terminal: the mod from this checkout
```

| Qayerda | Nimani bosib turish kerak | Ishlaydigan izoh |
| --- | --- | --- |
| Home | Send tugmasi | button is shifted |
| Home | Top up tugmasi | corners don't match the others |
| Home yoki Cards | karta egasining ismi | name is cut off |
| Home yoki Activity | yashil kategoriyadagi summa, masalan, maosh | income should be green |

Har biri koddagi bir qatorlik kichik xato. Reset skripti ularni `demo-start` git tag'idan, ya'ni xatolar qo'yilgan commit'dan tiklaydi. U iPhone 18 Pro simulyatorida ishlaydi; boshqa simulyator yoki `flutter devices` ro'yxatidagi istalgan qurilmani tanlash uchun `DEVICE` o'zgaruvchisiga uning nomini bering.

## Skript asosida yozib olish

Ekranni yozib olish uchun WidgetFix hisobotlarni barmoq o'rniga skriptdan ijro eta oladi. Ilovani director yoqilgan holda build qiling, so'ng qadamlarni `http://127.0.0.1:4748/next` manzilidan JSON ko'rinishida, har bir so'rovga bittadan bering (qadam qolmaganda 204 qaytaring):

```bash
flutter run --pid-file .widget_fix/flutter.pid --dart-define=WIDGET_FIX_DIRECTOR=true
```

```json
{"press": "card.holderName", "text": "The name is cut off"}
{"at": [321, 686], "text": "Income should be green"}
{"scroll": 260}
```

Bosish qadami ekrandagi `Fixable` widget'da yoki berilgan nuqtada izoh oynasini ochadi, matnni harfma-harf yozadi va yuboradi. Scroll qadami ekran o'rtasidagi vertikal scroll view'ni suradi. SwiftUI versiyasidagi `defaults` qadamining bu yerda muqobili yo'q: hot reload ilova holatini saqlaydi, shuning uchun qayta tiklanadigan tab yo'q.

## Ishlab chiqish

`scripts/test.sh` barcha tekshiruvlarni ishga tushiradi: marketplace va mod uchun `claude plugin validate`, mod testlari (`claude plugin test mod`), receiver testlari (`node --test`), paket va Tally uchun `flutter analyze` va `flutter test`, shuningdek ichida WidgetFix bo'lmasligi shart bo'lgan Tally release build'i.

## Litsenziya

MIT, [LICENSE](LICENSE) fayliga qarang.
