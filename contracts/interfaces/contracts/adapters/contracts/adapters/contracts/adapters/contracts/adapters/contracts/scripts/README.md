# OracleLens — Çok kaynaklı fiyat toplayıcı (medianizer)

OracleLens, farklı kaynaklardan (Chainlink, Uniswap V2 TWAP, manuel raporlayıcı vb.) fiyat okur, **taze** ve **tutarlı** olanları seçip **median** hesaplar. DAO hazinesi, lending parametreleri, limit kontrolleri gibi yerlerde “sağlam” tek bir fiyat çıktısı sunmak için idealdir.

## Özellikler
- Kaynak başına `IPriceSource.read() → (price, decimals, updatedAt)`
- Staleness filtresi (`maxAge`): eski veriler otomatik elenir
- **Normalizasyon**: tüm fiyatları `outDecimals`’a çevirir
- **Median**: aykırı değerleri bastırmak için median kullanır
- İsteğe bağlı **sapma** kontrolü (`maxDeviationBps`): median’dan çok sapan kaynakları reddeder
- Kaynak ekleme/kapama, config güncelleme (owner → ileride DAO’ya devredilebilir)
- Adapters:
  - `ChainlinkAdapter`
  - `UniV2TwapAdapter` (yerelde `update()` çağrısıyla pencere oluştur)
  - `ManualReporter` (acil/backup)

## Kurulum
```bash
npm install
npm run build
npm run node
# yeni terminal
npm run deploy:local
