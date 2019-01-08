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
skripti içermiyor. Bundan dolayı, aslında ``autoconf``'u kullanan ``buildconf`` skriptini kullanarak, bir ``configure`` 
skripti oluşturmanız gerekecek. Ek olarak, git reposu önceden oluşturulmuş bir ayrıştırıcı içermiyor, bu eksikliğin
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
* ``autoconf`` (2.59 ya da üzeri), ``configure`` skriptini oluşturmak için kullanılır.
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

``./buildconf`` skripti
-----------------------

Eğer yapılandırma işlemine git reposundan başladıysanız, ilk önce ``./buildconf`` skriptini çalıştırmanız
gerekmektedir. Bu skript, ``build/build.mk`` dosyasını çağırmaktan daha fazlasını yapar.

Bu makefile dosyalarının asıl görevi ``autoconf``'u ``./configure`` ve ``autoheader``skriptlerini üretmesi için çağırmaktır. Bu çağrıdan sonra da
``main/php_config.h.in`` şablonu oluşur.

Son bahsedilen dosya, yapılandırma başlık dosyası `` main / php_config.h``'ı oluşturmak için  kullanılacaktır.

Her iki program da kendi sonuçlarını `` configure.in`` dosyasından (PHP yapılandırma sürecinin çoğunu kapsayan)
üretir, "acinclude.m4" (çok sayıda PHP'ye özgü M4 makroları) ve "config.m4" dosyaları, bireysel uzantılar ve SAPIler
(çok sayıda ``m4`` dosyası) dosyaları.

İyi haber şu ki, eklenti yazmak veya çekirdekte değişiklikler yapmak, yapı sistemiyle
çok fazla etkileşim gerektirmeyecek. Sonradan küçük ``config.m4`` dosyaları yazmanız gerekecek fakat bunlar sadece
birkaç taneden oluşan ``acinclude.m4``'ün sağladığı yüksek-seviye makrolar olacak. Bunun haricinde daha
fazla ayrıntıya girmeyeceğiz.

``./buildconf`` skripti sadece iki seçeneğe sahip: ``--debug`` seçeneği autoconf ve
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

``./configure`` skripti
-----------------------

``./configure`` skripti bir kere oluşturulduktan sonra PHP yapınızı özelleştirmek için kullanabilirsiniz.
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

``--enable-debug`` enables debug mode, which has multiple effects: Compilation will run with ``-g`` to generate debug
symbols and additionally use the lowest optimization level ``-O0``. This will make PHP a lot slower, but make debugging
with tools like ``gdb`` more predictable. Furthermore debug mode defines the ``ZEND_DEBUG`` macro, which will enable
various debugging helpers in the engine. Among other things memory leaks, as well as incorrect use of some data
structures, will be reported.

``--enable-maintainer-zts`` enables thread-safety. This switch will define the ``ZTS`` macro, which in turn will enable
the whole TSRM (thread-safe resource manager) machinery used by PHP. Writing thread-safe extensions for PHP is very
simple, but only if make sure to enable this switch. Otherwise you're bound to forget a ``TSRMLS_*`` macro somewhere and
your code won't build in a thread-safe environment.

On the other hand you should not use either of these options if you want to perform performance benchmarks for your
code, as both can cause significant and asymmetrical slowdowns.

Note that ``--enable-debug`` and ``--enable-maintainer-zts`` change the ABI of the PHP binary, e.g. by adding additional
arguments to many functions. As such shared extensions compiled in debug mode will not be compatible with a PHP binary
built in release mode. Similarly a thread-safe extension is not compatible with a thread-unsafe PHP build.

Due to the ABI incompatibility ``make install`` (and PECL install) will put shared extensions in different directories
depending on these options:

* ``$PREFIX/lib/php/extensions/no-debug-non-zts-API_NO`` for release builds without ZTS
* ``$PREFIX/lib/php/extensions/debug-non-zts-API_NO`` for debug builds without ZTS
* ``$PREFIX/lib/php/extensions/no-debug-zts-API_NO`` for release builds with ZTS
* ``$PREFIX/lib/php/extensions/debug-zts-API_NO`` for debug builds with ZTS

The ``API_NO`` placeholder above refers to the ``ZEND_MODULE_API_NO`` and is just a date like ``20100525``, which is
used for internal API versioning.

For most purposes the configuration switches described above should be sufficient, but of course ``./configure``
provides many more options, which you'll find described in the help.

Apart from passing options to configure, you can also specify a number of environment variables. Some of the more
important ones are documented at the end of the configure help output (``./configure --help | tail -25``).

For example you can use ``CC`` to use a different compiler and ``CFLAGS`` to change the used compilation flags::

    ~/php-src> ./configure --disable-all CC=clang CFLAGS="-O3 -march=native"

In this configuration the build will make use of clang (instead of gcc) and use a very high optimization level
(``-O3 -march=native``).

``make`` ve ``make install``
----------------------------

After everything is configured, you can use ``make`` to perform the actual compilation::

    ~/php-src> make -jN    # where N is the number of cores

The main result of this operation will be PHP binaries for the enabled SAPIs (by default ``sapi/cli/php`` and
``sapi/cgi/php-cgi``), as well as shared extensions in the ``modules/`` directory.

Now you can run ``make install`` to install PHP into ``/usr/local`` (default) or whatever directory you specified using
the ``--prefix`` configure switch.

``make install`` will do little more than copy a number of files to the new location. Unless you specified
``--without-pear`` during configuration, it will also download and install PEAR. Here is the resulting tree of a default
PHP build:

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

A short overview of the directory structure:

* *bin/* contains the SAPI binaries (``php`` and ``php-cgi``), as well as the ``phpize`` and ``php-config`` scripts.
  It is also home to the various PEAR/PECL scripts.
* *etc/* contains configuration. Note that the default *php.ini* directory is **not** here.
* *include/php* contains header files, which are needed to build additional extensions or embed PHP in custom software.
* *lib/php* contains PEAR files. The *lib/php/build* directory includes files necessary for building extensions, e.g.
  the ``acinclude.m4`` file containing PHP's M4 macros. If we had compiled any shared extensions those files would live
  in a subdirectory of *lib/php/extensions*.
* *php/man* obviously contains man pages for the ``php`` command.

As already mentioned, the default *php.ini* location is not *etc/*. You can display the location using the ``--ini``
option of the PHP binary:

.. code-block:: none

    ~/myphp/bin> ./php --ini
    Configuration File (php.ini) Path: /home/myuser/myphp/lib
    Loaded Configuration File:         (none)
    Scan for additional .ini files in: (none)
    Additional .ini files parsed:      (none)

As you can see the default *php.ini* directory is ``$PREFIX/lib`` (libdir) rather than ``$PREFIX/etc`` (sysconfdir). You
can adjust the default *php.ini* location using the ``--with-config-file-path=PATH`` configure option.

Also note that ``make install`` will not create an ini file. If you want to make use of a *php.ini* file it is your
responsibility to create one. For example you could copy the default development configuration:

.. code-block:: none

    ~/myphp/bin> cp ~/php-src/php.ini-development ~/myphp/lib/php.ini
    ~/myphp/bin> ./php --ini
    Configuration File (php.ini) Path: /home/myuser/myphp/lib
    Loaded Configuration File:         /home/myuser/myphp/lib/php.ini
    Scan for additional .ini files in: (none)
    Additional .ini files parsed:      (none)

Apart from the PHP binaries the *bin/* directory also contains two important scripts: ``phpize`` and ``php-config``.

``phpize`` is the equivalent of ``./buildconf`` for extensions. It will copy various files from *lib/php/build* and
invoke autoconf/autoheader. You will learn more about this tool in the next section.

``php-config`` provides information about the configuration of the PHP build. Try it out:

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

The script is similar to the ``pkg-config`` script used by linux distributions. It is invoked during the extension
build process to obtain information about compiler options and paths. You can also use it to quickly get information
about your build, e.g. your configure options or the default extension directory. This information is also provided by
``./php -i`` (phpinfo), but ``php-config`` provides it in a simpler form (which can be easily used by automated tools).

Test ortamını çalıştırmak
-------------------------

If the ``make`` command finishes successfully, it will print a message encouraging you to run ``make test``:

.. code-block:: none

    Build complete.
    Don't forget to run 'make test'

``make test`` will run the PHP CLI binary against our test suite, which is located in the different *tests/* directories
of the PHP source tree. As a default build is run against approximately 9000 tests (less for a minimal build, more if
you enable additional extensions) this can take several minutes. The ``make test`` command is currently not parallel, so
specifying the ``-jN`` option will not make it faster.

If this is the first time you compile PHP on your platform, we encourage you to run the test suite. Depending on your
OS and your build environment you may find bugs in PHP by running the tests. If there are any failures, the script will
ask whether you want to send a report to our QA platform, which will allow contributors to analyze the failures. Note
that it is quite normal to have a few failing tests and your build will likely work well as long as you don't see
dozens of failures.

The ``make test`` command internally invokes the ``run-tests.php`` file using your CLI binary. You can run
``sapi/cli/php run-tests.php --help`` to display a list of options this script accepts.

If you manually run ``run-tests.php`` you need to specify either the ``-p`` or ``-P`` option (or an ugly environment
variable)::

    ~/php-src> sapi/cli/php run-tests.php -p `pwd`/sapi/cli/php
    ~/php-src> sapi/cli/php run-tests.php -P

``-p`` is used to explicitly specify a binary to test. Note that in order to run all tests correctly this should be an
absolute path (or otherwise independent of the directory it is called from). ``-P`` is a shortcut that will use the
binary that ``run-tests.php`` was called with. In the above example both approaches are the same.

Instead of running the whole test suite, you can also limit it to certain directories by passing them as arguments to
``run-tests.php``. E.g. to test only the Zend engine, the reflection extension and the array functions::

    ~/php-src> sapi/cli/php run-tests.php -P Zend/ ext/reflection/ ext/standard/tests/array/

This is very useful, because it allows you to quickly run only the parts of the test suite that are relevant to your
changes. E.g. if you are doing language modifications you likely don't care about the extension tests and only want to
verify that the Zend engine is still working correctly.

You don't need to explicitly use ``run-tests.php`` to pass options or limit directories. Instead you can use the
``TESTS`` variable to pass additional arguments via ``make test``. E.g. the equivalent of the previous command would
be::

    ~/php-src> make test TESTS="Zend/ ext/reflection/ ext/standard/tests/array/"

We will take a more detailed look at the ``run-tests.php`` system later, in particular also talk about how to write your
own tests and how to debug test failures.

Derleme problemlerini gidermek ve ``make clean`` komutu
-------------------------------------------------------

As you may know ``make`` performs an incremental build, i.e. it will not recompile all files, but only those ``.c``
files that changed since the last invocation. This is a great way to shorten build times, but it doesn't always work
well: For example, if you modify a structure in a header file, ``make`` will not automatically recompile all ``.c``
files making use of that header, thus leading to a broken build.

If you get odd errors while running ``make`` or the resulting binary is broken (e.g. if ``make test`` crashes it before
it gets to run the first test), you should try to run ``make clean``. This will delete all compiled objects, thus
forcing the next ``make`` call to perform a full build.

Sometimes you also need to run ``make clean`` after changing ``./configure`` options. If you only enable additional
extensions an incremental build should be safe, but changing other options may require a full rebuild.

A more aggressive cleaning target is available via ``make distclean``. This will perform a normal clean, but also roll
back any files brought by the ``./configure`` command invocation. It will delete configure caches, Makefiles,
configuration headers and various other files. As the name implies this target "cleans for distribution", so it is
mostly used by release managers.

Another source of compilation issues is the modification of ``config.m4`` files or other files that are part of the PHP
build system. If such a file is changed, it is necessary to rerun the ``./buildconf`` script. If you do the modification
yourself, you will likely remember to run the command, but if it happens as part of a ``git pull`` (or some other
updating command) the issue might not be so obvious.

If you encounter any odd compilation problems that are not resolved by ``make clean``, chances are that running
``./buildconf --force`` will fix the issue. To avoid typing out the previous ``./configure`` options afterwards, you
can make use of the ``./config.nice`` script (which contains your last ``./configure`` call)::

    ~/php-src> make clean
    ~/php-src> ./buildconf --force
    ~/php-src> ./config.nice
    ~/php-src> make -jN

One last cleaning script that PHP provides is ``./vcsclean``. This will only work if you checked out the source code
from git. It effectively boils down to a call to ``git clean -X -f -d``, which will remove all untracked files and
directories that are ignored by git. You should use this with care.
