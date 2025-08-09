Projemizde yapılacak tüm değişiklikler benden onay alınarak ve bana sorulacak sorular ile ne yapılacağından emin olunarak gerçekleştirilmelidir.

Projemizin durumu, özellikleri ve değişecekler :

- Uygulamamız backend tarafına 2 şekilde bağlanmaktadır.

  1 - Hotspot ile sabit ip : 192.168.4.1
  2 - Wi-Fi ile hostname : raspberrypi.local (mDNS kullanarak)

- Uygulamamızın ana sayfasına 4 adet card bulunmakta:

  1 - Nöbetçi Eczane Ayarları
  2 - Wi-Fi Ağ Ayarları
  3 - Ekran Ayarları
  4 - Medya Yönetimi

- Uygulamamızın şu anki halinde wi-fi yada hotspot bağlantısı kontrol edilerek bu cardlardan bazılarını
  aktif - deaktif hale getiriyoruz. Bu durum değişecek her iki bağlantıda da cardlar aktif olacak. Bu kısıtlama kaldıralacak.

- Nöbetçi Eczane Ayarları , Wi-Fi ayarları, Ekran ayarları sayfalarında API ile veri alış verişi yapılıyor.

  Bu alışveriş sırasında backend tarafında veri alındığında backend kendine restart atıyor ve biz bu durumu gözlemliyoruz sonrasında ana sayfaya dönüyoruz gibi bir durum var.

  Bu durum backend tarafında değişecek ve sistem restart atmadan hotreload yapacak. Dolayısı ile bu saylafarda bulunun 15 sn restart gecikme beklemesi ve toastları olmayacak. Mobil uygulamamızın genel çalışma prensibini API isteği gönderdiği sırada gelen cevaba göre davranmak olarak değiştireceğiz.
  Bunu adım adım yapacağız.

  İlk olarak Ekran ayarları sayfasında bu değişiklikleri uygulayacağız.
