.. highlight:: bash

PHP eklentilerini yapılandırmak
===============================

Artık PHP'nin kendisini nasıl derleyeceğinizi bildiğinize göre, ek uzantıları derlemeye devam edeceğiz. Derleme
işleminin nasıl çalıştığını ve hangi farklı seçeneklerin mevcut olduğunu tartışacağız.

Paylaşılan uzantıların yüklenmesi
---------------------------------

Önceki bölümden zaten bildiğiniz gibi, PHP uzantıları ya PHP ikili olarak statik olarak oluşturulabilir ya da
paylaşılan bir nesneye derlenebilir (``.so``). Statik bağlantılama, paketlenmiş uzantıların çoğu için varsayılandır;
oysa paylaşılan nesneler açıkça ``--enable-EXTNAME=shared`` veya ``--with-EXTNAME=shared`` anahtarları
``./configure``'a gönderilerek oluşturulabilir.

Statik uzantılar her zaman kullanılabilir olsa da, paylaşılan uzantıların ``extension`` ya da ``zend_extension`` ini
seçenekleri kullanılarak yüklenmesi gerekir. Her iki seçenek de ``.so`` dosyasına giden mutlak yolu veya
``extension_dir`` ayarına göre belirtilen bir yolu kullanır. (``zend_extension`` için göreceli(relative) yollar sadece
PHP 5.5'ten itibaren kullanılabilir, öncesinde mutlak(absolute) yollar kullanmak zorundaydık.)

Örnek olarak, bu ayar satırı kullanılarak derlenmiş bir PHP yapısını düşünün::

    ~/php-src> ./configure --prefix=$HOME/myphp \
                           --enable-debug --enable-maintainer-zts \
                           --enable-opcache --with-gmp=shared

Bu durumda hem opcache hem de GMP eklentileri ``modules/`` dizininde bulunan, paylaşılan nesnelere derlenir. Her
ikisini de ``extension_dir``'i değiştirerek veya mutlak yolu parametre olarak vererek yükleyebilirsiniz:

    ~/php-src> sapi/cli/php -dzend_extension=`pwd`/modules/opcache.so \
                            -dextension=`pwd`/modules/gmp.so
    # or
    ~/php-src> sapi/cli/php -dextension_dir=`pwd`/modules \
                            -dzend_extension=opcache.so -dextension=gmp.so

``make install`` adımında, her ikisi de ``.so`` dosyaları, PHP kurulumunuzun ``php-config --extension-dir`` komutunu
kullanarak bulabileceğiniz eklenti dizinine taşınır. Bu dizin, yukarıdaki derleme seçenekleri için
``/home/myuser/myphp/lib/php/extensions/no-debug-non-zts-MODULE_API`` olacaktır. Bu değer ``extension_dir`` ini
seçeneğinin de varsayılanı olacaktır, bu nedenle açıkça belirtmeniz gerekmez ve uzantıları doğrudan yükleyebilirsiniz::

    ~/myphp> bin/php -dzend_extension=opcache.so -dextension=gmp.so

Bu aklımıza şu soruyu getirir: Hangi mekanizmayı kullanmalısın? Paylaşılan nesneler temel bir PHP ikili dosyasına sahip
olmanıza ve php.ini üzerinden ek uzantılar yüklemenize izin verir. Dağıtımlar bunu, sade bir PHP paketi sağlayarak ve
uzantıları ayrı paketler olarak dağıtarak kullanır. Öte yandan, kendi PHP ikili kodunuzu derliyorsanız, buna ihtiyaç
duymazsınız, çünkü hangi uzantılara ihtiyacınız olduğunu zaten biliyorsunuz.

Genel bir kural olarak, PHP'nin kendisi tarafından paketlenen uzantılar için statik bağlantı kullanacak ve diğer
her şey için paylaşılan uzantıları kullanacaksınız. Bunun nedeni, gördüğünüz gibi, harici uzantıları paylaşılan
nesneler olarak oluşturmanın daha kolay (veya en azından daha az müdahaleci) olmasıdır. Diğer bir avantaj ise, PHP'yi
yeniden oluşturmadan eklentiyi güncelleyebilmenizdir.

.. [#] Kitapta daha sonra "normal" bir uzantı ile Zend uzantısı arasındaki farktan bahsedeceğiz. Şimdilik, Zend
       uzantılarının daha "düşük seviye" (örneğin opcache veya xdebug) olduğunu bilmek ve Zend Engine'in kendi
       çalışmalarına bağlanmak yeterli gelecektir.

PECL'den uzantı yükleme
-----------------------

PECL_, *PHP Extension Community Library*, PHP için çok sayıda uzantı sunar. Uzantılar ana PHP dağıtımından
kaldırıldığında, genellikle PECL'de var olmaya devam ederler. Benzer şekilde, şimdi PHP ile birlikte gelen birçok
uzantı daha önce PECL uzantılarıydı.

PHP derlemenizin konfigürasyon aşamasında ``--without-pear`` anahtarını belirtmediyseniz, ``make install`` PEAR'ın bir
parçası olarak PECL'yi indirip yükleyecektir. ``pecl`` betiğini ``$PREFIX/bin`` dizininde bulabilirsiniz. Eklentileri
yüklemek son derece basittir, ``pecl install EXTNAME``, Örneğin::

    ~/myphp> bin/pecl install apcu-4.0.2

Bu komut APCu_ uzantısını indirecek, derleyecek ve yükleyecektir. Sonuç, uzantı dizininizde bir  ``apcu.so`` dosyası
olacaktır; bu, ``extension=apcu.so`` ini 'seçeneğinin kullanılmasıyla yüklenebilir.

 ``pecl install``, son kullanıcılar için çok kullanışlı olsa da, eklenti geliştiricilerinin ilgisini çekmiyor. Aşağıda,
 uzantıları manuel olarak oluşturmanın iki yolunu açıklayacağız: Ya ana PHP kaynak ağacına alarak (bu statik bağlantıya
 izin verir) ya da harici bir derleme yaparak (yalnızca paylaşılan).

.. _PECL: http://pecl.php.net
.. _APCu: http://pecl.php.net/package/APCu

PHP kaynak ağacına uzantı ekleme
--------------------------------

Üçüncü taraf bir uzantı ile PHP ile birlikte gelen bir uzantı arasında temel bir fark yoktur. Böylece harici bir
eklentiyi PHP kaynak ağacına kopyalayarak ve daha sonra normal derleme prosedürünü kullanarak oluşturabilirsiniz. Bunun
örneğini APCu'yu kullanarak göstereceğiz.

Öncelikle, uzantının kaynak kodunu PHP kaynak ağacınızın ``ext/EXTNAME`` dizinine yerleştirmeniz gerekir. Uzantı git
üzerinde mevcutsa, bu, depoyu ``ext/`` içinden klonlamak kadar basittir::

    ~/php-src/ext> git clone https://github.com/krakjoe/apcu.git

Alternatif olarak, bir kaynak tarball'ı indirebilir ve çıkarabilirsiniz::

    /tmp> wget http://pecl.php.net/get/apcu-4.0.2.tgz
    /tmp> tar xzf apcu-4.0.2.tgz
    /tmp> mkdir ~/php-src/ext/apcu
    /tmp> cp -r apcu-4.0.2/. ~/php-src/ext/apcu

Uzantı, autoconf tarafından kullanılacak uzantıya özgü derleme talimatlarını belirten bir ``config.m4`` dosyası
içerecektir. Onları ``./configure``  betiğine dahil etmek için yeniden ``./buildconf``'u çalıştırmanız gerekir.
Konfigürasyon dosyasının gerçekten yenilenmesini sağlamak için, önceden silmeniz önerilir::

    ~/php-src> rm configure && ./buildconf --force

Şimdi mevcut yapılandırmanıza APCu eklemek için ``./config.nice`` komut dosyasını kullanabilir veya tamamen yeni bir
yapılandırma satırıyla başlayabilirsiniz::

    ~/php-src> ./config.nice --enable-apcu
    # or
    ~/php-src> ./configure --enable-apcu # --other-options

Sonunda asıl yapıyı oluşturmak için ``make -jN`` komutunu çalıştırın. ``--enable-apcu=shared`` anahtarını
kullanmadığımız için, uzantı statik olarak PHP ikilisi ile bağlantılıdır, yani kullanımı için ek bir işlem yapmanıza
gerek yoktur. Ortaya çıkan ikili dosyaları yüklemek için ``make install`` komutunu da kullanabilirsiniz.

``phpize`` kullanarak eklenti oluşturma
---------------------------------------

Ayrıca :ref:`building_php` bölümünde daha önce bahsedilen ``phpize`` komut dosyasını kullanarak PHP'den ayrı uzantılar
oluşturmak da mümkündür.

``phpize``, PHP için kullanılan ``./buildconf`` betiği ile benzer bir rol oynar: İlk olarak, PHP yapılandırma
sistem dosyalarınızı ``$PREFIX/lib/php/build`` dizininden kopyalayarak eklentinize dahil edecektir. Bu dosyalar
arasında ``acinclude.m4`` (PHP'nin M4 makroları), ``phpize.m4`` (``configure.in`` olarak değiştirilecek ve ana derleme
talimatlarını içeren dosya) ve ``run-tests.php`` gibi dosyalar bulunur.

Ardından ``phpize``, uzantı yapısını özelleştirmek için kullanılan bir ``./configure`` dosyası oluşturmak için
autoconf'u çağırır. Burada “--enable-apcu” komutunu iletmek gerekli değildir. Bunun yerine `` --with-php-config``,
ve `` php-config`` anahtarlarını scriptinizin yolunu belirtmek için kullanmalısınız.

    /tmp/apcu-4.0.2> ~/myphp/bin/phpize
    Configuring for:
    PHP Api Version:         20121113
    Zend Module Api No:      20121113
    Zend Extension Api No:   220121113

    /tmp/apcu-4.0.2> ./configure --with-php-config=$HOME/myphp/bin/php-config
    /tmp/apcu-4.0.2> make -jN && make install

Eklentileri oluştururken, daima ``--with-php-config`` anahtarını belirtmelisiniz (PHP'nin tek bir global kurulumuna
sahip değilseniz), aksi takdirde ``./configure`` hangi PHP sürümünün ve bayraklarının oluşturulacağını doğru bir
şekilde belirleyemez. ``php-config`` betiğini belirtmek aynı zamanda ``make install``'ın oluşturmuş olduğu ``.so``
dosyasını (``/`` dizini içinde bulabileceğiniz) doğru eklenti dizinine taşımasını sağlar. ``run-tests.php`` dosyası
``phpize`` aşamasında da kopyalandığından, uzantı testlerini ``make test`` (veya testleri çalıştırmak için açık bir
çağrı) kullanarak çalıştırabilirsiniz.

Derlenmiş nesnelerin kaldırılması için ``make clean`` komutu da mevcuttur ve artımlı derleme bir değişiklikten sonra
başarısız olursa, uzantının tamamını yeniden oluşturmaya zorlamanıza izin verir. Ek olarak phpize ``phpize --clean``
komutu üzerinden bir temizlik seçeneği sunar. Bu, ``phpize`` ile içeri alınan tüm dosyaları ve ``/configure`` betiği
ile oluşturulan dosyaları kaldıracaktır.

Uzantılarla ilgili bilgileri görüntüleme
----------------------------------------

PHP CLI ikilisi(binary), uzantılar hakkında bilgi görüntülemek için çeşitli seçenekler sunar. Yüklü tüm uzantıları
listeleyecek olan ``-m`` parametresini zaten biliyorsunuz. Bunu aynı zamanda bir uzantının doğru yüklendiğini
doğrulamak için de kullanabilirsiniz::

    ~/myphp/bin> ./php -dextension=apcu.so -m | grep apcu
    apcu

Reflection işlevini ortaya çıkaran ``--r`` ile başlayan birkaç anahtar daha var. Örneğin, bir uzantı yapılandırmasını
görüntülemek için ``--ri`` kullanabilirsiniz::

    ~/myphp/bin> ./php -dextension=apcu.so --ri apcu
    apcu

    APCu Support => disabled
    Version => 4.0.2
    APCu Debugging => Disabled
    MMAP Support => Enabled
    MMAP File Mask =>
    Serialization Support => broken
    Revision => $Revision: 328290 $
    Build Date => Jan  1 2014 16:40:00

    Directive => Local Value => Master Value
    apc.enabled => On => On
    apc.shm_segments => 1 => 1
    apc.shm_size => 32M => 32M
    apc.entries_hint => 4096 => 4096
    apc.gc_ttl => 3600 => 3600
    apc.ttl => 0 => 0
    # ...

``--re`` anahtarı, bir uzantı tarafından eklenen tüm dahili ayarları, sabitleri, işlevleri ve sınıfları listeler:

.. code-block:: none

    ~/myphp/bin> ./php -dextension=apcu.so --re apcu
    Extension [ <persistent> extension #27 apcu version 4.0.2 ] {
      - INI {
        Entry [ apc.enabled <SYSTEM> ]
          Current = '1'
        }
        Entry [ apc.shm_segments <SYSTEM> ]
          Current = '1'
        }
        # ...
      }

      - Constants [1] {
        Constant [ boolean APCU_APC_FULL_BC ] { 1 }
      }

      - Functions {
        Function [ <internal:apcu> function apcu_cache_info ] {

          - Parameters [2] {
            Parameter #0 [ <optional> $type ]
            Parameter #1 [ <optional> $limited ]
          }
        }
        # ...
      }
    }

``--re`` anahtarı yalnızca normal uzantılar için çalışır, Zend uzantıları için bunun yerine ``--rz`` kullanılır. Bunu
opcache'de deneyebilirsiniz::

    ~/myphp/bin> ./php -dzend_extension=opcache.so --rz "Zend OPcache"
    Zend Extension [ Zend OPcache 7.0.3-dev Copyright (c) 1999-2013 by Zend Technologies <http://www.zend.com/> ]

Gördüğünüz gibi, bu herhangi bir faydalı bilgi göstermiyor. Bunun nedeni, opcache’in hem normal bir uzantıyı hem de
Zend uzantısını kaydetmesidir; burada, önceki tüm ini ayarları, sabitleri ve işlevleri içerir. Yani bu özel durumda
hala ``--re`` kullanmanız gerekir. Diğer Zend uzantıları, bilgilerini ``--rz`` yoluyla da sağlar.

..
    nikic: Commented out for now. building_php.rst already mentions ABI incompatibility for zts / debug / api version.
    This has more detail regarding the 3 different API numbers, but it doesn't really become clear what they mean, and
    I don't know that either (it seems like we just have too many and they should be reduced to just PHP Api No and
    Zend Api No.)

    Extensions API compatibility
    ****************************

    Extensions are very sensitive to 5 major factors. If they dont fit, the extension wont load into PHP and will be useless :

        * PHP Api Version
        * Zend Module Api No
        * Zend Extension Api No
        * Debug mode
        * Thread safety

    The *phpize* tool recall you some of those informations.
    So if you have built a PHP with debug mode, and try to make it load and use an extension which's been built without
    debug mode, it simply wont work. Same for the other checks.

    *PHP Api Version* is the number of the version of the internal API. *Zend Module Api No* and *Zend Extension Api No*
    are respectively about PHP extensions and Zend extensions API.

    Those numbers are later passed as C macros to the extension beeing built, so that it can itself checks against those
    parameters and take different code paths based on C preprocessor ``#ifdef``\s As those numbers are passed to the
    extension code as macros, they are written in the extension structure, so that anytime you try to load this extension in
    a PHP binary, they will be checked against the PHP binary's own numbers.
    If they mismatch, then the extension will not load, and an error message will be displayed.

    If we look at the extension C structure, it looks like this::

        zend_module_entry foo_module_entry = {
            STANDARD_MODULE_HEADER,
            "foo",
            foo_functions,
            PHP_MINIT(foo),
            PHP_MSHUTDOWN(foo),
            NULL,
            NULL,
            PHP_MINFO(foo),
            PHP_FOO_VERSION,
            STANDARD_MODULE_PROPERTIES
        };

    What is interesting for us so far, is the ``STANDARD_MODULE_HEADER`` macro. If we expand it, we can see::

        #define STANDARD_MODULE_HEADER_EX sizeof(zend_module_entry), ZEND_MODULE_API_NO, ZEND_DEBUG, USING_ZTS
        #define STANDARD_MODULE_HEADER STANDARD_MODULE_HEADER_EX, NULL, NULL

    Notice how ``ZEND_MODULE_API_NO``, ``ZEND_DEBUG``, ``USING_ZTS`` are used.


    If you look at the default directory for PHP extensions, it should look like ``no-debug-non-zts-20090626``. As you'd
    have guessed, this directory is made of distinct parts joined together : debug mode, followed by thread safety
    information, followed by the Zend Module Api No.
    So by default, PHP tries to help you navigating with extensions.

    .. note::

        Usually, when you become an internal developper or an extension developper, you will usually have to play with the debug parameter, and if you have to deal with the Windows platform, threads will show up as well. You can end with compiling the same extension several times against several cases of those parameters.

    Remember that every new major/minor version of PHP change parameters such as the PHP Api Version, that's why you need to recompile extensions against a newer PHP version.

    .. code-block:: none

        > /path/to/php54/bin/phpize -v
        Configuring for:
        PHP Api Version:         20100412
        Zend Module Api No:      20100525
        Zend Extension Api No:   220100525

        > /path/to/php55/bin/phpize -v
        Configuring for:
        PHP Api Version:         20121113
        Zend Module Api No:      20121212
        Zend Extension Api No:   220121212

        > /path/to/php53/bin/phpize -v
        Configuring for:
        PHP Api Version:         20090626
        Zend Module Api No:      20090626
        Zend Extension Api No:   220090626

    .. note::

        *Zend Module Api No* is itself built with a date using the *year.month.day* format. This is the date of the day the API changed and was tagged.
        *Zend Extension Api No* is the Zend version followed by *Zend Module Api No*.
