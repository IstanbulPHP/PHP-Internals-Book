.. highlight:: bash

.. _building_php:

PHP'yi yapılandırmak
====================

Bu bölüm, PHP'yi, eklenti geliştirme veya çekirdek üzerinde modifikasyonlar yapabilmeye uygun şekilde derlemeyi
açıklayacaktır.

Anlatım, sadece Unix ve türevleri olan işletim sistemlerini kapsamaktadır. Eğer PHP'yi Windows
işletim sistemi üzerinde derlemek istiyorsanız, `adım adım yapılandırma talimatlarını`__ inceleyin [#]_.

Bu bölüm aynı zamanda, PHP yapılandırma sisteminin nasıl çalıştığına ve hangi araçları kullandığına
dair genel bir bakış açısı sağlar, detaylı açıklamalar bu kitabın kapsamı dışındadır.

.. __: https://wiki.php.net/internals/windows/stepbystepbuild

.. [#] Sorumluluk reddi: PHP'yi Windows'ta derleme esnasında doğabilecek olumsuz etkilerden sorumlu değiliz.

Neden paketleri kullanmıyorsun?
-------------------------------

PHP'yi kullanıyorsanız, büyük ihtimalle paketleri yüklerken ``sudo apt-get install php`` gibi bir komut
kullandınız. Gerçek derleme işleminden bahsetmeye geçmeden önce, elle derleme yapmanın gerekliliğini ve
neden sadece önceden oluşturulmuş paketleri kullanamayacağınızı anlatmamız gerekiyor. 
Bunun birkaç nedeni var:

Öncelikle şunu bilmeniz gerekir ki, önceden oluşturulmuş paketlerde gerekli PHP dosyalarının yalnızca release
hali bulunur. Fakat, istediğimiz derleme işlemini yapabilmeniz için header dosyaları, derleme eklentileri gibi 
dosyalar da gereklidir. Neyse ki bize gerekli olan dosyaları, ``php-dev`` denilen geliştirme paketini yükleyerek
sağlayabiliriz. Valgring ya da gdb gibi araçlarla hata ayıklama işlemi yapmak istersek, ekstra olarak hata ayıklama
sembollerini yüklememiz gerekmektedir. Hata ayıklama araçlarının düzgün çalışmasını ``php-dbg`` hata ayıklama 
sembollerini yükleyerek çözebiliriz.

Aslında header'leri ve hata ayıklama ayıklama sembollerini yüklemiş bile olsanız hala PHP'nin release versiyonu ile
çalışıyorsunuz. Yani şu anlama geliyor ki: PHP yüksek optimizasyon ile yapılandırılmış ve bu da sizin hata ayıklama
işlemlerinizi zorlaştıracak. Dahası, release versiyonları hafıza sızıntıları veya tutarsız veri yapıları hakkında
size uyarı vermeyecektir. Aynı zamanda, önceden yapılandırılmış paketlerde iş parçacıklarının güvenliği
sağlanmamaktadır, bu da geliştirme sırasında çok faydalı olacaktır. 

Bir diğer konu ise, hemen hemen tüm dağıtımlar PHP'ye ekstra yamalar uygulamaktadır. Bazı durumlarda bu yamalar,
yapılandırma ile ilgili küçük değişiklikler içerirken, bazen ise Suhosin gibi son derece müdahaleci olabilirler.
Bu yamaların bazıları opcache gibi düşük seviye eklentilerle uyumsuzluk yaratmalarıyla bilinirler.

PHP sadece `php.net`_ üzerinde yayınlanan versiyonu için destek vermektedir. Eğer hata bildirimi yapmak, yama göndermek,
ya da eklenti yazmak için yardım kanallarımızı kullanmak istiyorsanız, daima resmi PHP versiyonu üzerinde
çalışmalısınız. Bu kitapta PHP'den söz ederken tamamen resmi sürümden bahsediyor olacağız.

.. _`php.net`: http://www.php.net

Kaynak kodunu edinmek
---------------------

PHP'yi yapılandırmadan önce, kaynak kodunu edinmeniz gerekmektedir. Kodu edinmenin iki yolu var: Arşiv dosyasını
`PHP'nin indirme sayfasından`_ ya da git reposundan `git.php.net`_ (ya da
`Github`_ ikiz bağlantısından) edinebilirsiniz.

Yukarıdaki her iki durum için yapılandırma işlemi farklı olarak gerçekleşiyor: Git reposundaki arşiv bir ``configure`` 
betiği içermiyor. Bundan dolayı, aslında ``autoconf``'u kullanan ``buildconf`` betiğini kullanarak, bir ``configure`` 
betiği oluşturmanız gerekecek. Ek olarak, git reposu önceden oluşturulmuş bir ayrıştırıcı içermiyor, bu eksikliğin
giderilmesi için bilgisayarınızda bison'un yüklü olması gerekiyor.

PHP kaynak kodunu git üzerinden edinmenizi tavsiye ediyoruz, bu yöntem ile kurulumunuz en güncel halde kalacak ve
kodunuzu farklı PHP versiyonları ile deneyebileceksiniz. Aynı zamanda, PHP yaması veya pull request yapmak 
istediğinizde yine kodu git üzerinden çekmiş olmanız gerekmektedir.

Repoyu klonlamak için, aşağıdaki komutları kabuk(shell) üzerinde çalıştırın::

    ~> git clone http://git.php.net/repository/php-src.git
    ~> cd php-src
    # ilk olarak master branch'inde olacaksınız, stabil bir versiyona geçmek isterseniz
    # aşağıdaki komutu kullanabilirsiniz:
    ~/php-src> git checkout PHP-5.5

git checkout ile ilgili problem yaşıyorsanız, PHP wiki'sindeki `Git SSS`_'a bakabilirsiniz. Git SSS aynı zamanda,
PHP için geliştirme yapıp katkıda bulunmak istiyorsanız, buna uygun nasıl bir kurulum yapmanız
gerektiğini de açıklıyor. Ek olarak, çoklu klasör mantığıyla, farklı PHP versiyonları üzerinde nasıl
çalışılabileceğinize dair ayarların da açıklaması mevcut. Bu yöntem, yazdığınız eklentileri veya
yaptığınız değişiklikleri farklı versiyonlar üzerinde, farklı ayarlarla test etmede faydalı olacaktır.

Devam etmeden önce, paket yöneticiniz vasıtasıyla bazı bağlılıkları yüklemeniz gerekmektedir (büyük ihtimalle
ilk üçü yüklü olarak gelecektir):

* ``gcc`` veya başka bir derleyici paketi.
* ``libc-dev``, başlıkları ve C standart kütüphanesini içerir.
* ``make``, PHP'nin kullandığı kurulum aracı.
* ``autoconf`` (2.59 ya da üzeri), ``configure`` betiğini oluşturmak için kullanılır.
* ``automake`` (1.4 ya da üzeri), ``Makefile.in`` dosyalarını oluşturur.
* ``libtool``, paylaşımlı kütüphaneleri yönetmeye yardımcı olur.
* ``bison`` (2.4 ya da üzeri), PHP ayrıştırıcısını oluşturmak için kullanılır.
* (opsiyonel) ``re2c``, PHP lekserini/ayrıştırıcısını oluşturmak için kullanılır. Eğer kaynak kodunu git reposundan edindiyseniz, içerisinde daha önceden oluşturulmuş bir lekser/ayrıştırıcı bulunmaktadır, üzerinde değişiklik yapmak isterseniz,sadece re2c'e ihtiyacınız olacaktır.

Bunların hepsini Debian/Ubuntu üzerinde, aşağıdaki komutu çalıştırarak yükleyebilirsiniz::

    ~/php-src> sudo apt-get install build-essential autoconf automake libtool bison re2c

``./configure`` aşamasında etkinleştirdiğiniz eklentilere bağlı olarak, PHP farklı kütüphanelere de ihtiyaç duyabilir.
Bunları yüklerken, ilgili paketin sonu ``-dev`` ya da ``-devel`` biten versiyonu varsa, onu yükleyin.
``dev`` etiketi barındırmayan paketler genelde gerekli başlık dosyalarını içermezler. Örneğin varsayılan bir
PHP yapılandırması libxml'e ihtiyaç duyar, bunu da ``libxml2-dev`` olarak yüklersiniz.

Eğer Debian ya da Ubuntu kullanıyorsanız, you can use ``sudo apt-get build-dep php5`` komutuyla birçok bağlılığı
tek seferde yükleyebilirsiniz. Sadece varsayılan yapılandırmayı istiyorsanız, bunların birçoğu gereksiz olacaktır.

.. _PHP'nin indirme sayfasından: http://www.php.net/downloads.php
.. _git.php.net: http://git.php.net
.. _Github: http://www.github.com/php/php-src
.. _Git SSS: https://wiki.php.net/vcs/gitfaq

Yapılandırma önizlemesi
-----------------------

Bireysel kurulum ayarlarına daha yakından bakmadan önce, "varsayılan" PHP yapılandırması için
aşağıdaki komutları çalıştırmanız gerekmektedir::

    ~/php-src> ./buildconf     # only necessary if building from git
    ~/php-src> ./configure
    ~/php-src> make -jN

Daha hızlı bir yapılandırma için, ``N`` kısmını işlemciniz içi uygun çekirdek sayısıyla değiştirebilirsiniz
(çekidek sayısını görüntülemek için bu komutu çalıştırın ``grep "cpu cores" /proc/cpuinfo``).

Varsayılan olarak PHP komut satırı(CLI), ortak ağ geçidi(CGI) ve sunucu uygulaması programlama
arabirimleri(SAPI) için binary dosyalar oluşturur, bunlar sırasıyla ``sapi/cli/php`` ve
``sapi/cgi/php-cgi`` dosyalarıdır. Herşeyin yolunda gittiğinden emin olmak için, ``sapi/cli/php -v``
komutunu çalıştırın.

Ayrıca, PHP'yi ``/usr/local`` içerisine yüklemek için, ``sudo make install`` komutunu da çalıştırabilirsiniz.
Konfigürasyon aşamasında, hedef klasör ``--prefix`` parametresi verilerek değiştirilebilir::

    ~/php-src> ./configure --prefix=$HOME/myphp
    ~/php-src> make -jN
    ~/php-src> make install

Burada ``$HOME/myphp``, ``make install`` aşaması boyunca kullanılacak yüklemenin lokasyonudur.
Şunu unutmayın ki, PHP'yi yüklemek bu iş için gerekli değil, fakat PHP'yi eklenti geliştirme dışında da
kullanacaksanız sizin için uygun olabilir.

Şimdi bireysel kurulum aşamalarına daha yakından bakalım!

``./buildconf`` betiği
-----------------------

Eğer yapılandırma işlemine git reposundan başladıysanız, ilk önce ``./buildconf`` betiğini çalıştırmanız
gerekmektedir. Bu betik, ``build/build.mk`` dosyasını çağırmaktan daha fazlasını yapar.

Bu makefile dosyalarının asıl görevi ``autoconf``'u ``./configure`` ve ``autoheader``betiklerini üretmesi için çağırmaktır. Bu çağrıdan sonra da
``main/php_config.h.in`` şablonu oluşur.

Son bahsedilen dosya, yapılandırma başlık dosyası `` main / php_config.h``'ı oluşturmak için  kullanılacaktır.

Her iki program da kendi sonuçlarını `` configure.in`` dosyasından (PHP yapılandırma sürecinin çoğunu kapsayan)
üretir, "acinclude.m4" (çok sayıda PHP'ye özgü M4 makroları) ve "config.m4" dosyaları, bireysel uzantılar ve SAPIler
(çok sayıda ``m4`` dosyası) dosyaları.

İyi haber şu ki, eklenti yazmak veya çekirdekte değişiklikler yapmak, yapı sistemiyle
çok fazla etkileşim gerektirmeyecek. Sonradan küçük ``config.m4`` dosyaları yazmanız gerekecek fakat bunlar sadece
birkaç taneden oluşan ``acinclude.m4``'ün sağladığı yüksek-seviye makrolar olacak. Bunun haricinde daha
fazla ayrıntıya girmeyeceğiz.

``./buildconf`` betiği sadece iki seçeneğe sahip: ``--debug`` seçeneği autoconf ve
autoheader çağırılırken, uyarı bastırmayı devredışı bırakır. buildsystem üzerinde çalışmadığınız sürece,
bu seçenek ilginizi çok da çekmeyecektir.

İkincisi ise, dağıtım paketlerinde (eğer paketlenmiş bir kaynak kodu indirmiş 
ve yeni bir ``./configure`` oluşturmakistiyorsanız) ``./buildconf`` çalıştırabilmenizi
sağlayan ve yapılandırma önbelleği olan ``config.cache`` ve ``autom4te.cache/``'i temizlemeyi sağlayan 
``--force`` seçeneği.

Eğer git deponuzu(repository) ``git pull`` komutuyla (ya da başka bir komutla) güncellerseniz ve 

If you update your git repository using ``git pull`` (or some other command) and ``make`` işlemi sırasında
garip hatalar alırsanız, bu yapılandırmanızda bir şeylerin değiştiği ve ``./buildconf --force`` komutunu
çalıştırmanız gerektiği anlamına gelir.

``./configure`` betiği
-----------------------

``./configure`` betiği bir kere oluşturulduktan sonra PHP yapınızı özelleştirmek için kullanabilirsiniz.
``--help`` yazarak tüm desteklenen komutları görüntüleyebilirsiniz::

    ~/php-src> ./configure --help | less

Yardım menüsünün ilk kısmı, tüm autoconf tabanlı yapılandırma komut dosyaları tarafından desteklenen
çeşitli seçenekleri listeler. Bunlardan biri, `` install make`` tarafından kullanılan
kurulum dizinini değiştiren ``prefix = DIR``'dir. Bir başka kullanışlı seçenek olarak ``-C``,
``config.cache`` dosyasındaki çeşitli testlerin sonuçlarını önbelleğe alır ve sonraki ``./configure`` çağrılarını
hızlandırır. Bu seçeneği kullanmak, yalnızca çalışan bir yapınız olduğunda ve farklı bir yapılandırmaya
hızlıca geçmek istediğinizde mantıklıdır.

Genel autoconf seçeneklerinden ayrı olarak PHP'ye özgü birçok ayar vardır. Örneğin,
``--enable-NAME`` ve ``--disable-NAME`` parametreleri kullanılarak hangi uzantıların ve SAPI'lerin derlenmesi
gerektiğini belirleyebilirsiniz. Uzantı veya SAPI'lerin dış bağımlılıkları varsa bunun yerine 
``--with-NAME`` ve ``--without-NAME`` kullanmanız gerekir. Eğer ``NAME`` tarafından ihtiyaç duyulan kütüphane
varsayılan konumda bulunmuyorsa(eğer kendiniz derlediyseniz), `--with-NAME=DIR`` parametresi kullanılarak konum
belirtebilirsiniz.

PHP, CLI ve CGI SAPI'lerini ve birçok uzantıyı oluşturacaktır. PHP ikili dosyanızın(binary),
`` -m`` seçeneğini kullanarak hangi uzantılarını içerdiğini öğrenebilirsiniz.
Varsayılan bir PHP 5.5 yapılandırması için sonuç şöyle görünecektir:

.. code-block:: none

    ~/php-src> sapi/cli/php -m
    [PHP Modules]
    Core
    ctype
    date
    dom
    ereg
    fileinfo
    filter
    hash
    iconv
    json
    libxml
    pcre
    PDO
    pdo_sqlite
    Phar
    posix
    Reflection
    session
    SimpleXML
    SPL
    sqlite3
    standard
    tokenizer
    xml
    xmlreader
    xmlwriter

Şimdi, CGI SAPI'nin yanı sıra belirteç(tokenizer) ve sqlite3 uzantılarını derlemeyi durdurmak ve bunun yerine
opcache ve gmp'yi etkinleştirmek istediğinizde, ilgili yapılandırma komutu::

    ~/php-src> ./configure --disable-cgi --disable-tokenizer --without-sqlite3 \
                           --enable-opcache --with-gmp

Varsayılan olarak, birçok eklenti statik olarak derlenir, diğer bir deyişle; ortaya çıkan ikili kodun parçası olur.
Sadece opcache uzantısı varsayılan olarak paylaşılır, yani; ``modules/`` klasörü içerisinde ``opcache.so`` paylaşımlı
objesi oluşturulur. ``--enable-NAME=shared`` ya da ``--with-NAME=shared`` yazarak, diğer uzantıların da birer paylaşımlı
obje olarak derlenmesini sağlayabilirsiniz (fakat her uzantı bunu desteklemez). Bir sonraki bölümde,
paylaşılan uzantıların nasıl kullanılacağı hakkında konuşacağız.

Hangi anahtarı kullanmanız gerektiğini ve bir uzantının varsayılan olarak etkin olup olmadığını öğrenmek için, 
``./configure --help`` komutuna bakınız. Eğer anahtar ``--enable-NAME`` ya da ``--with-NAME`` ise, bu uzantının
varsayılan olarak derlenmediğini ve etkinleştirilmesi gerektiğini belirtir. Diğer bir seçenek olan `--disable-NAME``
veya ``--without-NAME`` anahtarları, uzantının varsayılan olarak derlendiğini ve devredışı bırakılabileceğini gösterir.

Bazı eklentiler daima derlenmiş olarak gelir ve devredışı bırakılamaz. Minimum uzantı içeren bir yapılandırma
elde etmek için ``--disable-all`` opsiyonu kullanılmalıdır::

    ~/php-src> ./configure --disable-all && make -jN
    ~/php-src> sapi/cli/php -m
    [PHP Modules]
    Core
    date
    ereg
    pcre
    Reflection
    SPL
    standard


``--disable-all`` opsiyonu, fazla fonksiyonellik barındırmayan ve hızlı bir build istediğinizde çok kullanışlıdır
(Örneğin: dil değişiklikleri uygulamak istediğinizde). Mümkün olan en küçük yapılandırma için ek olarak 
``--disable-cgi`` anahtarını belirttiğinizde, sadece CLI ikilisi(binary) oluşturulur.

Eklenti geliştirirken veya PHP üzerinde çalışırken **her zaman** belirtmeniz gereken iki anahtar daha vardır:

``--enable-debug``, birden fazla etkiye sahip olan ayıklama modunu etkinleştirir: Derleme, ayıklama sembollerini
oluşturmak için ``-g`` parametresiyle çalışır ve en düşük optimizasyon seviyesi olan ``-O0`` kullanılır.
Bu PHP'nin çok daha fazla yavaş hale getirecek, fakat ``gdb`` gibi araçlarla hata ayıklamayı daha
öngörülebilir hale getirecek. Ayrıca hata ayıklama modu, motorda(engine) çeşitli hata ayıklama yardımcılarını
etkinleştirecek olan ``ZEND_DEBUG`` makrosunu tanımlar. Diğer şeylerin yanı sıra hafıza sızıntısı, veri yapılarının
yanlış kullanımı rapor edilecektir. 

``--enable-maintainer-zts`` iş parçacığı güvenliğini(thread-safety) sağlar. Bu anahtar, PHP tarafından kullanılan tüm
TSRM(İş Parçacığı Güvenli Kaynak Yöneticisi) makinelerini mümkün kılacak olan ``ZTS`` makrosunu tanımlar. PHP için
güvenli iş parçacığı(thread-safe) uzantıları yazmak basittir, ancak bu anahtarı etkinleştirdiğinizden emin olmalısınız.
Aksi takdirde bir yerde ``TSRMLS_*`` makrosunu unutmak zorundasınız ve kodunuz iş parçacığı güvenli(thread-safe) bir
ortamda oluşturulmayacaktır.

Öte yandan, kodunuz için performans ölçümü gerçekleştirmek istiyorsanız bu seçeneklerin ikisini de önemli ve asimetrik
yavaşlamalara sebep olabileceğinden kullanmamalısınız.

``--enable-debug`` ve ``--enable-maintainer-zts`` anahtarlarının PHP ikili(binary) kodunun ABI'ini değiştirdiğine
dikkat edin, örneğin; birçok fonksiyona ek argümanlar eklemek gibi. Hata ayıklama modunda derlenen paylaşılan uzantılar
PHP ikilisi(binary) ile uyumlu olmayacağından serbest bırakma modunda(release mode) yerleşiktir. Benzer şekilde,
iş parçacığı güvenli(thread-safe) bir uzantı iş parçacığı güvensiz(thread-unsafe) bir PHP yapılandırması ile
uyumlu değildir.

ABI uyumsuzluğu nedeniyle ``make install`` (ve PECL install) komutu paylaşımlı eklentilerini aşağıdaki seçeneklere
bağlı olarak farklı dizinlere koyacağız:

* ``$PREFIX/lib/php/extensions/no-debug-non-zts-API_NO`` ZTS içermeyen serbest bırakma sürümleri için(release builds)
* ``$PREFIX/lib/php/extensions/debug-non-zts-API_NO`` ZTS içermeyen hata ayıklama sürümleri için(debug builds)
* ``$PREFIX/lib/php/extensions/no-debug-zts-API_NO`` ZTS içeren serbest bırakma sürümleri için(release builds)
* ``$PREFIX/lib/php/extensions/debug-zts-API_NO`` ZTS içeren hata ayıklama sürümleri için(debug builds)

Yukarıdaki ``API_NO`` yer tutucusu(placeholder) ``ZEND_MODULE_API_NO``'ya karşılık gelir ve bu, ``20100525`` gibi bir
tarihtir, dahili API sürümlemesi için kullanılır.

Çoğu amaç için yukarıdaki açıklanan yapılandırma anahtarları yeterli olur, ancak elbette ``./configure`` yardım
kısmında açıklandığı gibi birçok seçenek sunar.

Yapılandırılacak seçeneklerin yanı sıra, bir dizi ortam değişkeni de belirleyebilirsiniz. En önemlilerinden bazıları,
'yapılandır' (configure) yardım çıktısının (``./configure --help | tail -25``) sonunda belirtilmiştir.

Örneğin, farklı bir derleyici kullanmak için ``CC`` ve kullanılmış derleme bayraklarını değiştirmek için ``CFLAGS``
kullanabilirsiniz::

    ~/php-src> ./configure --disable-all CC=clang CFLAGS="-O3 -march=native"

Bu yapılandırmada, derleme clang (gcc yerine) kullanacak ve çok yüksek bir optimizasyon seviyesi
kullanacaktır (``-O3 -march=native``).

``make`` ve ``make install``
----------------------------

Her şey ayarlandıktan sonra, gerçek derlemeyi gerçekleştirmek için ``make`` komutunu kullanabilirsiniz::

    ~/php-src> make -jN    # N, çekirdeklerin sayısıdır

Bu işlemin ana sonucu, etkin SAPI'ler için (varsayılan olarak ``sapi/cli/php`` ve ``sapi/cgi/php-cgi``)
PHP ikilisinin(binary) yanısıra, ``modules/`` dizinindeki paylaşımlı uzantılar olacaktır.

Şimdi PHP'yi ``/usr/local``(varsayılan) dizine yüklemek için ``make install`` komutunu çalıştırabilirsiniz ya da
farklı bir dizine yüklemek istiyorsanız, ``--prefix`` anahtarını kullanarak bu işlemi gerçekleştirebilirsiniz.

``make install`` yeni lokasyona dosya kopyalama işleminden çok daha fazlasını yapar. Yapılandırma sırasında
``--without-pear`` anahtarını belirtmediyseniz, PEAR da indirilip yüklenecektir. Aşağıda varsayılan PHP derlemesinin
sonuç ağacını bulabilirsiniz:

.. code-block:: none

    > tree -L 3 -F ~/myphp

    /home/myuser/myphp
    |-- bin
    |   |-- pear*
    |   |-- peardev*
    |   |-- pecl*
    |   |-- phar -> /home/myuser/myphp/bin/phar.phar*
    |   |-- phar.phar*
    |   |-- php*
    |   |-- php-cgi*
    |   |-- php-config*
    |   `-- phpize*
    |-- etc
    |   `-- pear.conf
    |-- include
    |   `-- php
    |       |-- ext/
    |       |-- include/
    |       |-- main/
    |       |-- sapi/
    |       |-- TSRM/
    |       `-- Zend/
    |-- lib
    |   `-- php
    |       |-- Archive/
    |       |-- build/
    |       |-- Console/
    |       |-- data/
    |       |-- doc/
    |       |-- OS/
    |       |-- PEAR/
    |       |-- PEAR5.php
    |       |-- pearcmd.php
    |       |-- PEAR.php
    |       |-- peclcmd.php
    |       |-- Structures/
    |       |-- System.php
    |       |-- test/
    |       `-- XML/
    `-- php
        `-- man
            `-- man1/

Dizin yapısına kısa bir genel bakış:

* *bin/*, SAPI ikili(binary) dosyalarını(``php`` and ``php-cgi``) ve ``phpize`` and ``php-config`` betiklerini içerir.
  Ayrıca çeşitli PEAR / PECL scriptlerine de ev sahipliği yapmaktadır.
* *etc/*, konfigürasyonları barındırır. Varsayılan *php.ini* dizininin burada **olmadığını** unutmayalım.
* *include/php*, ek uzantılar oluşturmak veya PHP'yi özel yazılıma yerleştirmek için gereken başlık dosyalarını içerir.
* *lib/php*, PEAR dosyalarını içerir. *lib/php/build* dizini, uzantı yapılandırmak için gerekli dosyaları içerir,
  örneğin: PHP'nin M4 makrolarını içeren ``acinclude.m4`` dosyası. Herhangi bir paylaşılan uzantıyı derlemiş olsaydık,
  bu dosyalar *lib/php/extensions* dizini altında yaşardı.
* *php/man* açıkça, ``php`` komutu için kılavuz sayfalarını içerir.

Daha önce de belirtildiği gibi, varsayılan *php.ini* lokasyonu *etc/* değildir. Gerçek lokasyonu, PHP ikilisine(binary)
``--ini`` anahtarını göndererek öğrenebilirsiniz:

.. code-block:: none

    ~/myphp/bin> ./php --ini
    Configuration File (php.ini) Path: /home/myuser/myphp/lib
    Loaded Configuration File:         (none)
    Scan for additional .ini files in: (none)
    Additional .ini files parsed:      (none)

Gördüğünüz üzere, varsayılan *php.ini* dizini ``$PREFIX/etc``(sysconfdir)'den ziyade ``$PREFIX/lib``(libdir) olarak
gözüküyor. ``--with-config-file-path=PATH`` konfigürasyon seçeneğini kullanarak varsayılan *php.ini* konumunu
ayarlayabilirsiniz.

Ayrıca, ``make install`` komutunun ini dosyası oluşturmayacağını unutmayın. *php.ini* dosyasından yararlanmak
istiyorsanız, oluşturmak sizin sorumluluğunuzdadır. Örneğin, varsayılan geliştirme yapılandırmasından
kopyalayabilirsiniz:

.. code-block:: none

    ~/myphp/bin> cp ~/php-src/php.ini-development ~/myphp/lib/php.ini
    ~/myphp/bin> ./php --ini
    Configuration File (php.ini) Path: /home/myuser/myphp/lib
    Loaded Configuration File:         /home/myuser/myphp/lib/php.ini
    Scan for additional .ini files in: (none)
    Additional .ini files parsed:      (none)

PHP ikili(binary) dosyalarından ayrı olarak *bin/* dizini de iki önemli komut betiği içerir: 
``phpize`` ve ``php-config``.

``phpize`` uzantılar için ``./buildconf`` ile eşdeğerdir. *lib/php/build* dizininden çeşitli dosyalar kopyalar ve
autoconf/autoheader'ı çağırır. Bir sonraki bölümde, bu araçlar hakkında daha fazla bilgi edineceksiniz.

``php-config``, PHP derlemesinin yapılandırması hakkında bilgi sağlar. Deneyin:

.. code-block:: none

    ~/myphp/bin> ./php-config
    Usage: ./php-config [OPTION]
    Options:
      --prefix            [/home/myuser/myphp]
      --includes          [-I/home/myuser/myphp/include/php -I/home/myuser/myphp/include/php/main -I/home/myuser/myphp/include/php/TSRM -I/home/myuser/myphp/include/php/Zend -I/home/myuser/myphp/include/php/ext -I/home/myuser/myphp/include/php/ext/date/lib]
      --ldflags           [ -L/usr/lib/i386-linux-gnu]
      --libs              [-lcrypt   -lresolv -lcrypt -lrt -lrt -lm -ldl -lnsl  -lxml2 -lxml2 -lxml2 -lcrypt -lxml2 -lxml2 -lxml2 -lcrypt ]
      --extension-dir     [/home/myuser/myphp/lib/php/extensions/debug-zts-20100525]
      --include-dir       [/home/myuser/myphp/include/php]
      --man-dir           [/home/myuser/myphp/php/man]
      --php-binary        [/home/myuser/myphp/bin/php]
      --php-sapis         [ cli cgi]
      --configure-options [--prefix=/home/myuser/myphp --enable-debug --enable-maintainer-zts]
      --version           [5.4.16-dev]
      --vernum            [50416]

Bu betik, linux dağıtımları tarafından kullanılan ``pkg-config`` betiğine benzer. Derleyici seçenekleri ve yolları
hakkında bilgi edinmek için uzantı oluşturma işlemi sırasında çağrılır. Ayrıca, derlemeniz hakkında hızlı bir şekilde
bilgi edinmek için de kullanabilirsiniz, örneğin: yapılandırma seçeneklerinizi veya varsayılan uzantı dizini. Bu bilgi
``./php -i`` (phpinfo) tarafından da sağlanmıştır, ancak ``php-config`` daha basit bir biçimde (otomatik araçlar
tarafından kolayca kullanılabilir) sağlanır.

Test ortamını çalıştırmak
-------------------------

``make`` komutu başarıyla tamamlanırsa ``make test``'i çalıştırmanız için bir mesaj yazdıracaktır:

.. code-block:: none

    Build complete.
    Don't forget to run 'make test'

``make test`` PHP kaynak ağacının farklı *test/* dizinlerinde bulunan test takımımıza karşı PHP CLI ikili(binary)
dosyasını çalıştıracaktır. Varsayılan bir derleme yaklaşık 9000 teste karşı çalıştırıldığı için (minimum derleme için
daha az, ek uzantıları etkinleştirirseniz daha fazla) bu birkaç dakika sürebilir. ``make test`` komutu şu anda paralel
değildir, bu nedenle ``-jN`` seçeneğini belirlemek daha hızlı hale getirmez.

PHP'yi platformunuzda ilk kez kullanıyorsanız, test takımını çalıştırmanızı öneririz. İşletim sisteminize ve yapı
ortamınıza bağlı olarak, testleri çalıştırarak PHP'de hata bulabilirsiniz. Herhangi bir başarısızlık olursa, senaryo,
QA platformumuza bir rapor göndermek isteyip istemediğinizi soracaktır, bu da katılımcıların başarısızlıkları analiz
etmesine olanak sağlayacaktır. Birkaç başarısız testin yapılmasının oldukça normal olduğunu ve yapınızın düzinelerce
hata görmediğiniz sürece muhtemelen işe yarayacağını unutmayın.

``make test`` komutu dahili olarak CLI ikili sisteminizi kullanarak ``run-tests.php`` dosyasını çağırır.
Bu betiğin kabul ettiği seçeneklerin bir listesini görüntülemek için ``sapi/cli/php run-tests.php --help`` komutunu
çalıştırabilirsiniz.

Eğer ``run-tests.php``'i elle çalıştırıyorsanız, ``-p`` veya ``-P`` seçeneğini (veya çirkin bir ortam değişkenini)
belirtmeniz gerekir::

    ~/php-src> sapi/cli/php run-tests.php -p `pwd`/sapi/cli/php
    ~/php-src> sapi/cli/php run-tests.php -P

``-p`` test edilecek bir ikili  dosyayı açıkça belirtmek için kullanılır. Tüm testleri doğru bir şekilde çalıştırmak
için bunun mutlak bir yol (ya da denilen dizinden bağımsız olarak) olması gerektiğini unutmayın. ``-P``,
``run-tests.php`` ile çağrılan ikili yodsyayı kullanacak bir kısayoldur.  Yukarıdaki örnekte her iki yaklaşım da
aynıdır.

Test takımının tamamını çalıştırmak yerine, ``run-tests.php``'ye argümanlar şeklinde göndererek belirli dizinlerle
sınırlayabilirsiniz. Örneğin, sadece Zend motorunu, yansıma uzantısını ve dizi fonksiyonlarını test etmek için:

    ~/php-src> sapi/cli/php run-tests.php -P Zend/ ext/reflection/ ext/standard/tests/array/

Bu çok kullanışlıdır, çünkü yalnızca test grubunun değişikliklerinizle ilgili kısımlarını hızlıca çalıştırmanıza izin
verir. Örneğin, dilde değişiklik yapıyorsanız, uzatma testlerini umursamayıp sadece Zend motorunun hala doğru
çalıştığını doğrulamak istiyorsunuzdur.

Seçenekleri geçmek veya dizinleri sınırlamak için açıkça ``run-tests.php`` kullanmanıza gerek yoktur. Bunun yerine
``make test`` yoluyla ek argümanlar iletmek için ``TESTS`` değişkenini kullanabilirsiniz. Örneğin bir önceki komutun 
karşılığı şu şekilde olacaktır::

    ~/php-src> make test TESTS="Zend/ ext/reflection/ ext/standard/tests/array/"

``run-tests.php`` sistemini daha sonra detaylı olarak inceleyeceğiz, özellikle kendi testlerinizi nasıl yazacağınız ve
test hatalarına karşı nasıl bir hata ayıklama yapacağınız hakkında bilgi vereceğiz.

Derleme problemlerini gidermek ve ``make clean`` komutu
-------------------------------------------------------

Bildiğiniz gibi, ``make`` artıklı bir derleme yapar, yani tüm dosyaları yeniden derlemez, ancak son çağrılmasından bu
yana değişen ``.c`` dosyalarını derler. Bu derleme zamanını kısaltmak için harika bir yoldur, ancak her zaman iyi sonuç
vermez: Örneğin, bir başlık dosyasındaki herhangi bir yapıyı değiştirirseniz, ``make``, tüm ``.c`` dosyalarının
yapımını otomatik olarak derlemez, böylece kırık bir yapıya yol açar.

Eğer ``make``'i çalıştırırken garip hatalar alırsanız ya da sonuç olarak ortaya çıkan ikili sistem bozulursa (örneğin 
``make test``, ilk testi çalıştırmadan önce çökerse), ``make clean`` komutunu kullanmalısınız. Bu, derlenmiş tüm
nesneleri siler, böylece bir sonraki ``make`` çağrısını tam derleme yapmaya zorlar.

Bazen, ``./configure`` seçeneklerini değiştirdikten sonra ``make clean`` komutunu çalıştırmanız da gerekebilir.
Yalnızca ek uzantıları etkinleştirirseniz, artımlı bir yapı güvenli olmalıdır, ancak diğer seçenekleri değiştirmek tam
bir yeniden oluşturma gerektirebilir.

Daha agresif bir temizlik ``make distclean`` komutuyla mümkündür. Bu normal bir temizleme gerçekleştirecek, ancak
``./configure`` komut çağrısı ile getirilen dosyaları da geri alacaktır. Yapılandırma önbelleklerini, Makefiles,
yapılandırma başlıkları ve diğer çeşitli dosyaları siler. Adından da belli olduğu gibi "dağıtımı temizler", bu nedenle
çoğunlukla yayın yöneticileri tarafından kullanılır.

Derleme sorunlarının bir başka kaynağı da ``config.m4`` dosyalarının veya PHP derleme sisteminin bir parçası olan diğer
dosyaların değiştirilmesidir. Eğer böyle bir dosya değişirse, ``./buildconf`` betiğini yeniden çalıştırmak gerekir.
Değişikliği kendiniz yaparsanız, muhtemelen komutu çalıştırmayı hatırlayacaksınız, ancak bir `` git pull`` (ya da başka
bir güncelleme komutunun) parçası olarak gerçekleşirse, komutu çalıştırmayı hatırlamanız zor olabilir.

Eğer ``make clean`` ile çözülmeyen herhangi bir garip derleme problemiyle karşılaşırsanız, muhtemelen bu sorunu çözmek
için ``./buildconf --force`` size bir şans verecektir. Önceki ``./configure`` seçeneklerini sonradan yazmaktan kaçınmak
için ``./config.nice``  betiğini kullanabilirsiniz (son ``./configure`` çağrınızı içerir)::

    ~/php-src> make clean
    ~/php-src> ./buildconf --force
    ~/php-src> ./config.nice
    ~/php-src> make -jN

Son olarak, PHP'nin sağladığı bir diğer temizlik betiği ``./vcsclean``'dir. Bu betik kaynak kodunu git'ten alırsanız
çalışacaktır. Git tarafından görmezden gelinen tüm izsiz dosyaları ve dizinleri ``git clean -X -f -d`` komutuyla
kaldırır. Bu yüzden dikkatli kullanmalısınız.
