# ICECLUB Customer App

The Flutter app customers use to order ice. It sits beside `dealer_app`, `driver_app` and `admin_panel`, and shares their theme and structure.

## Run it

```
flutter pub get
flutter run
flutter test
flutter build apk --release
```

Demo login: any valid 10-digit mobile number, with OTP `123456`.

## What is in it

| Area | Pages |
| --- | --- |
| Getting started | Welcome slides, login, OTP, your details, delivery area check |
| Shopping | Home, shop, category, product, reviews, search, favourites |
| Buying | Cart, coupons, checkout, payment, payment failed, order placed |
| Orders | Active, delivered and cancelled lists, order details, live tracking, bill, cancel, rate, report a problem, reported problems |
| Regular and large orders | Subscriptions (list, new, edit, details), ice planner, bulk order, my enquiries |
| Money | Wallet, add money, reward points, payment methods, offers, offer details, refer and earn |
| Account | Account, edit profile, saved addresses, add and edit address, notifications, notification settings, settings, delete account |
| Help | Help centre, contact us, tickets, new ticket, ticket chat, ice safety guide, find a store, feedback, about, terms, privacy, refunds |

## Structure

```
lib/
  app/        router, routes, bottom tabs
  core/       theme, shared widgets, storage, formatters
  features/   one folder per feature, split into domain, data and presentation
```

## What is still demo

- There is no server yet, so this app shares no data with the Admin Panel, Dealer App or Rider App.
- All data is saved on the phone. Orders move along by themselves and the rider's position is simulated.
- No SMS is sent, and no real money moves. Payment, wallet top-ups and referral rewards all need a real backend and payment gateway.
- Push notifications are not connected.

## Needed from the business before launch

- A logo for the customer app. The current icon is the dealer logo without its "Dealer App" label.
- Real prices, pack sizes, coupons, reward rules, delivery fees and the list of PIN codes served. All of these are placeholders.
- Whether cube ice is fit for drinks. The app treats tube and cube ice as fit, and crushed, block and slab ice as chilling only.
- Final terms, privacy and refund wording, and company GST details for tax invoices.
- A paid map provider. The public OpenStreetMap tile servers are not meant for production apps.
- Separate photos for tube, slab and block ice, which currently share images.
