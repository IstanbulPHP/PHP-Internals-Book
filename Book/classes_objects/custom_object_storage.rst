Özel nesne depolama
===================

Önceki bölüm, basit iç sınıfların oluşturulması için zemin hazırladı. Burada açıklanan özelliklerin çoğu oldukça basit
olmalıdır, çünkü kullanıcı tarafındaki PHP'de olduğu gibi çalışırlar, sadece daha ayrıntılı olarak ifade edilirler. Öte
yandan, bu bölüm, kullanıcı tarafındaki sınıflarda mevcut olmayan alanlara girecektir: Özel nesne depolamasının
oluşturulması ve erişilmesi.

Nesneler nasıl oluşturulur?
---------------------------

İlk adım olarak, nesnenin PHP'de nasıl yaratıldığına bakalım. Bunun için ``object_and_properties_init`` makrosu ya da
basit kuzenlerinden biri kullanılır ::

    // SomeClass türünde bir nesne oluşturun ve özelliklerine properties_hashtable'dan verin
    zval *obj;
    MAKE_STD_ZVAL(obj);
    object_and_properties_init(obj, class_entry_of_SomeClass, properties_hashtable);

    // SomeClass türünde bir nesne oluşturun (varsayılan özelliklerle)
    zval *obj;
    MAKE_STD_ZVAL(obj);
    object_init_ex(obj, class_entry_of_SomeClass);
    // = object_and_properties_init(obj, class_entry_of_SomeClass, NULL)

    // Varsayılan bir nesne oluşturun (stdClass)
    zval *obj;
    MAKE_STD_ZVAL(obj);
    object_init(obj);
    // = object_init_ex(obj, NULL) = object_and_properties_init(obj, NULL, NULL)

Son durumda, yani bir ``stdClass`` nesnesini oluştururken muhtemelen daha sonra özellikler eklemek isteyeceksiniz. Bu
genellikle önceki bölümdeki ``zend_update_property`` işlevleri ile yapılmaz, bunun yerine ``add_property`` makroları
kullanılır::

    add_property_long(obj, "id", id);
    add_property_string(obj, "name", name, 1); // 1, dizenin kopyalanması gerektiği anlamına gelir
    add_property_bool(obj, "isAdmin", is_admin);
    // ayrıca _null(), _double(), _stringl(), _resource() and _zval()

Peki, bir nesne oluşturulduğunda gerçekte ne olur? Öğrenmek için ``_object_and_properties_init`` işlevine bakalım::

    ZEND_API int _object_and_properties_init(
        zval *arg, zend_class_entry *class_type, HashTable *properties ZEND_FILE_LINE_DC TSRMLS_DC
    ) {
        zend_object *object;

        if (class_type->ce_flags
            & (ZEND_ACC_INTERFACE|ZEND_ACC_IMPLICIT_ABSTRACT_CLASS|ZEND_ACC_EXPLICIT_ABSTRACT_CLASS)
        ) {
            char *what = (class_type->ce_flags & ZEND_ACC_INTERFACE)                 ? "interface"
                       : ((class_type->ce_flags & ZEND_ACC_TRAIT) == ZEND_ACC_TRAIT) ? "trait"
                       : "abstract class";
            zend_error(E_ERROR, "Cannot instantiate %s %s", what, class_type->name);
        }

        zend_update_class_constants(class_type TSRMLS_CC);

        Z_TYPE_P(arg) = IS_OBJECT;
        if (class_type->create_object == NULL) {
            Z_OBJVAL_P(arg) = zend_objects_new(&object, class_type TSRMLS_CC);
            if (properties) {
                object->properties = properties;
                object->properties_table = NULL;
            } else {
                object_properties_init(object, class_type);
            }
        } else {
            Z_OBJVAL_P(arg) = class_type->create_object(class_type TSRMLS_CC);
        }
        return SUCCESS;
    }

İşlev temel olarak üç şey yapar: İlk önce sınıfın gerçek anlamda başlatılabileceğini doğrular, ardından sınıf
sabitlerini çözer (bu yalnızca ilk başlatmada yapılır ve ayrıntıları burada önemli değildir). Bundan sonra önemli kısım
gelir: İşlev, sınıfın ``create_object`` işleyicisine sahip olup olmadığını kontrol eder. Eğer bir tanesine sahipse,
varsayılan ``zend_objects_new`` uygulaması yoksa, kullanılır (ve ayrıca özellikler başlatılır).

Sonra, ``zend_objects_new`` aşağıdakileri yapar::

    ZEND_API zend_object_value zend_objects_new(
        zend_object **object, zend_class_entry *class_type TSRMLS_DC
    ) {
        zend_object_value retval;

        *object = emalloc(sizeof(zend_object));
        (*object)->ce = class_type;
        (*object)->properties = NULL;
        (*object)->properties_table = NULL;
        (*object)->guards = NULL;
        retval.handle = zend_objects_store_put(*object,
            (zend_objects_store_dtor_t) zend_objects_destroy_object,
            (zend_objects_free_object_storage_t) zend_objects_free_object_storage,
            NULL TSRMLS_CC
        );
        retval.handlers = &std_object_handlers;
        return retval;
    }

Yukarıdaki kod üç ilginç şey içeriyor. Öncelikle tanımlandığı gibi, ``zend_object`` yapısı::

    typedef struct _zend_object {
        zend_class_entry *ce;
        HashTable *properties;
        zval **properties_table;
        HashTable *guards; /* protects from __get/__set ... recursion */
    } zend_object;

Bu "standart" nesne yapısıdır. Oluşturma için kullanılan sınıf girdisini, bir hashtable özelliğini, bir "tablo"
özelliğini ve özyinelemeyi koruma için bir karma tablosunu içerir. ``properties`` ve ``properties_table`` arasındaki
farkın tam olarak ne olduğu, bu bölümün sonraki bölümlerinde ele alınacaktır; bu noktada, yalnızca ikincisinin sınıfta
ilan edilen özellikler için kullanıldığını ve ilk olarak ilan edilmeyen özellikler için kullanıldığını bilmelisiniz.
``guards`` mekanizmasının nasıl işlediği de daha sonra ele alınacaktır.

``zend_objects_new`` işlevi yukarıda belirtilen standart nesne yapısını tahsis eder ve başlatır. Daha sonra nesne
verisini nesne deposuna koymak için ``zend_objects_store_put`` çağırır. Nesne deposu dinamik olarak yeniden
boyutlandırılmış bir ``zend_object_store_bucket``\s dizisinden başka bir şey değildir::

    typedef struct _zend_object_store_bucket {
        zend_bool destructor_called;
        zend_bool valid;
        union _store_bucket {
            struct _store_object {
                void *object;
                zend_objects_store_dtor_t dtor;
                zend_objects_free_object_storage_t free_storage;
                zend_objects_store_clone_t clone;
                const zend_object_handlers *handlers;
                zend_uint refcount;
                gc_root_buffer *buffered;
            } obj;
            struct {
                int next;
            } free_list;
        } bucket;
    } zend_object_store_bucket;

Buradaki ana bölüm, ``void *object`` nesnesinin üyesinde saklanan nesneyi içeren ``_store_object`` yapısı ve ardından
yıkım, serbest bırakma ve klonlama işleyicileridir. Bu yapıda bazı ek şeyler de var, örneğin “refcount”
özelliğine sahip, çünkü nesne deposundaki bir nesneye aynı anda birkaç zval'dan başvuruda bulunabiliyor ve PHP'nin kaç
tane izini tutması gerektiği oradaki referanslar tarafından sonradan serbest bırakılabilir. Ek olarak, ``handlers``
işleyicileri nesnesi de saklanır (bu, imha için gereklidir) ve bir GC kök tamponu (PHP'ler döngü toplayıcısının nasıl
çalıştığı daha sonraki bir bölümde ele alınacaktır).

``zend_objects_new`` işlevine geri dönersek, yaptığı en son şey, işleyicileri varsayılan ``std_object_handlers``'a
ayarlamaktır.

create_object öğesini geçersiz kılma
------------------------------------

Özel nesne depolamayı kullanmak istediğinizde, temel olarak yukarıdaki üç adımı tekrarlayacaksınız: İlk önce, standart
nesneyi bir altyapı olarak içerecek olan nesneyi ayırır ve başlatırsınız. Sonra onu birkaç işleyiciyle birlikte nesne
deposuna koyarsınız. Ve son olarak, nesne işleyicileri yapınızı atarsınız.

Bunu yapmak için `create_object` sınıf işleyicisini geçersiz kılmanız gerekir. İşte bunun nasıl göründüğünü gösteren
basit bir örnek (satır içi açıklamalarla)::

    zend_class_entry *test_ce;

    /* Nesnelerimiz için kullanılacak nesne işleyicileri depolamak için (gerçek bir global) değişkene ihtiyacımız var.
     * Nesne işleyicileri MINIT'te başlatıldı. */
    static zend_object_handlers test_object_handlers;

    /* Özel nesne yapımız. İlk üye olarak bir `zend_object` değeri (bir işaretçi değil!) içermesi gerekir, 
     * ardından istediği ilave özellikleri takip edin. */
    typedef struct _test_object {
        zend_object std;
        long additional_property;
    } test_object;

    /* Bu, nesne serbest bırakıldığında çağrılacak olan işleyicidir.
     * Bu işleyici std nesnesini imha etmelidir (bu özellik özellikleri vb. Serbest bırakacaktır)
     * ve ayrıca nesne yapısını kendisi serbest bırakmalıdır.
     * (Ve tahsis edilen başka kaynaklar varsa, bunların da burada serbest bırakılması gerekir.) */
    static void test_free_object_storage_handler(test_object *intern TSRMLS_DC)
    {
        zend_object_std_dtor(&intern->std TSRMLS_CC);
        efree(intern);
    }

    /* Bu nesne oluşturmak için kullanılan işleyicidir. Sınıf girişini alır (bunu genişleten sınıflar
     * için de kullanılır, bu nedenle sınıf girişinin iletilmesi gerekir) ve bir nesne değeri (nesne 
     * deposuna bir tutamaç ve nesne işleyicisine bir işaretçi yapısı döndürür). */
    zend_object_value test_create_object_handler(zend_class_entry *class_type TSRMLS_DC)
    {
        zend_object_value retval;

        /* Dahili nesne yapısını atayın ve sıfırlayın. Kural olarak, iç yapıyı tutan değişken genellikle 
         * `intern` olarak adlandırılır. */
        test_object *intern = emalloc(sizeof(test_object));
        memset(intern, 0, sizeof(test_object));

        /* Temel std zend_object başlatılması gerekiyor.  */
        zend_object_std_init(&intern->std, class_type TSRMLS_CC);

        /* Özellikleri kendiniz kullanmasanız bile, object_properties_init () öğesini
         * çağırmalısınız, çünkü extending sınıfları özellikleri kullanabilir. (Genelde
         * yapacağınız işlerin çoğu, genişleyen sınıfları kırmamak adınadır). */
        object_properties_init(&intern->std, class_type);

        /* Dahili nesneyi, varsayılan dtor işleyicisi ve özel serbest işleyicimiz ile,
         * nesne deposuna yerleştirin. Son NULL parametresi şimdilik boş bırakılan klon 
         * işleyicisidir. */
        retval.handle = zend_objects_store_put(
            intern,
            (zend_objects_store_dtor_t) zend_objects_destroy_object,
            (zend_objects_free_object_storage_t) test_free_object_storage_handler,
            NULL TSRMLS_CC
        );

        /* Özelleştirilmiş nesne işleyicileri atama */
        retval.handlers = &test_object_handlers;

        return retval;
    }

    /* Şimdilik fonksiyon yok */
    const zend_function_entry test_functions[] = {
        PHP_FE_END
    };

    PHP_MINIT_FUNCTION(test2)
    {
        /* Her zamanki sınıf kaydı... */
        zend_class_entry tmp_ce;
        INIT_CLASS_ENTRY(tmp_ce, "Test", test_functions);
        test_ce = zend_register_internal_class(&tmp_ce TSRMLS_CC);

        /* Sınıf girişine nesne oluşturma işleyicisini atayın */
        test_ce->create_object = test_create_object_handler;

        /* Özel nesne işleyicileri varsayılan nesne işleyicileri için ilklendir. Daha sonra 
         * normal olarak bireysel işleyicileri geçersiz kılarsınız, ancak şimdilik bunları 
         * varsayılanlara bırakalım. */
        memcpy(&test_object_handlers, zend_get_std_object_handlers(), sizeof(zend_object_handlers));

        return SUCCESS;
    }

Yukarıdaki kod henüz pek kullanışlı değil, ancak hemen hemen tüm iç PHP sınıflarının temel yapısını gösterir.

Nesne deposu işleyicileri
-------------------------

Daha önce de belirtildiği gibi, üç nesne depolama işleyicisi vardır: Biri imha etmek, biri serbest bırakmak, diğeri
klonlamak için.

İlk başta kafa karıştırıcı olan şey, hem bir dtor işleyicisinin hem de aynı şey hakkında yaptıkları gibi görünen
ücretsiz bir işleyicinin olmasıdır. Bunun nedeni, PHP'nin, önce yıkıcı olarak adlandırılan ve sonra nesnenin serbest
bırakıldığı iki aşamalı bir nesne imha sistemine sahip olmasıdır. Her iki faz birbirinden ayrı olabilir.

Özellikle bu, komut dosyası sona erdiğinde hala yaşayan nesneler de olur. Onlar için PHP ilk önce tüm dtor
işleyicilerini çağıracak (herhangi bir kayıtlı kapatma işlevini çağırdıktan hemen sonra), ancak yalnızca uygulayıcı
kapanmasının bir parçası olarak nesneleri daha sonra boşaltacaktır. Bu yıkım ve boşaltma ayrımı, kapatma sırasındaki
yıkıcıların çalıştırılmadığından emin olmak için gereklidir, aksi takdirde kullanıcı kodu bir yarı kapanma ortamında
çalıştırılır. Bu ayrılma olmadan, kapatma sırasında herhangi bir ``zval_ptr_dtor`` çağrısı patlayabilir.

Dtor işleyicilerinin başka bir özelliği de mutlaka çağrılmaya gerek *olmamasıdır*. Örneğin. Bir yıkıcı ``öl`` diyorsa,
kalan yıkıcılar atlanır.

Bu nedenle, temel olarak iki işleyici arasındaki fark, dtor'un kullanıcı kodu çalıştırabilmesi, ancak mutlaka
çağrılmaya gerek olmaması, diğer taraftan özgür olarak çağrılması, ancak her zaman PHP kodları çalıştırmamaları
gerektiğidir. Bu nedenle çoğu durumda yalnızca özel bir serbest işleyici belirtir ve dtor işleyicisi olarak
``zend_objects_destroy_object`` işlevini kullanırsınız (varsa), varsayılan davranışını sağlar. Bir kez daha,
``__destruct`` kullanmasanız bile, bu işleyiciyi yine de belirtmelisiniz, aksi halde miras sınıfları da
kullanamaz.

Şimdi sadece klon işleyicisi kaldı. Burada semantik basit olmalı, ancak kullanımı biraz daha zor.
Bir klon işleyicisinin böyle görünür::

    static void test_clone_object_storage_handler(
        test_object *object, test_object **object_clone_target TSRMLS_DC
    ) {
        /* Yeni bir obje oluştur */
        test_object *object_clone = emalloc(sizeof(test_object));
        zend_object_std_init(&object_clone->std, object->std.ce TSRMLS_CC);
        object_properties_init(&object_clone->std, object->std.ce);

        /* Burada herhangi bir ek klonlama işlemi yap */
        object_clone->additional_property = object->additional_property;

        /* Klonlanan objeyi geri döndür */
        *object_clone_target = object_clone;
    }

Klon işleyicisi daha sonra ``zend_objects_store_put``'a son argüman olarak iletilir::

    retval.handle = zend_objects_store_put(
        intern,
        (zend_objects_store_dtor_t) zend_objects_destroy_object,
        (zend_objects_free_object_storage_t) test_free_object_storage_handler,
        (zend_objects_store_clone_t) test_clone_object_storage_handler
        TSRMLS_CC
    );

Ancak bu klonlama işleyicisinin çalışmasını sağlamak için henüz yeterli değildir: Varsayılan olarak, nesne depolama
klonlama işleyicisi basitçe yoksayılır. Çalışması için, nesne işleyicileri yapısındaki varsayılan klonlama işleyicisini
``zend_objects_store_clone_obj`` ::

    memcpy(&test_object_handlers, zend_get_std_object_handlers(), sizeof(zend_object_handlers));
    test_object_handler.clone_obj = zend_objects_store_clone_obj;

Ancak standart klonlama işleyicisinin (``zend_objects_clone_obj``) üzerine yazması kendi sorunlarıyla birlikte gelir:
Şimdi özellikler (gerçek özelliklerde olduğu gibi, özel nesne deposundakiler değil) kopyalanmayacak ve aynı zamanda
``__clone`` yöntemi çağrılmayacak. Bu nedenle çoğu iç sınıf, nesne saklama klonu işleyicisi üzerinden fazladan tur
yapmak yerine doğrudan klonlama için kendi nesne işleyicisini belirler. Bu yaklaşım biraz daha fazla kazanç ile
birlikte geliyor. Örneğin, varsayılan klonlama işleyicisi şöyle görünür::

    ZEND_API zend_object_value zend_objects_clone_obj(zval *zobject TSRMLS_DC)
    {
        zend_object_value new_obj_val;
        zend_object *old_object;
        zend_object *new_object;
        zend_object_handle handle = Z_OBJ_HANDLE_P(zobject);

        /* yaratmanın üzerine yazılmadığını varsayalım, yani klon üzerine yazılana
         * bağlı olduğunda, o zaman kendi üzerine yazılmalıdır. */
        old_object = zend_objects_get_address(zobject TSRMLS_CC);
        new_obj_val = zend_objects_new(&new_object, old_object->ce TSRMLS_CC);

        zend_objects_clone_members(new_object, new_obj_val, old_object, handle TSRMLS_CC);

        return new_obj_val;
    }
Bu işlev ilk önce ``zend_object*`` yapısını ``zend_objects_get_address`` kullanarak nesne deposundan alır, ardından
aynı sınıf girişine sahip yeni bir nesne oluşturur (``zend_objects_new`` kullanarak) ve sonra
``zend_objects_clone_members`` işlevini çağırır. Bu da (adından da anlaşılacağı gibi) özellikleri klonlar, ancak varsa
``__clone`` yöntemini de çağırır.

Özel bir nesne klonlama işleyicisi benzer görünüyor; temel fark, ``zend_objects_new`` çağırmak yerine,
``create_object`` işleyicimizi çağırmaktır::

    static zend_object_value test_clone_handler(zval *object TSRMLS_DC)
    {
        /* Eski nesnenin iç yapısını al */
        test_object *old_object = zend_object_store_get_object(object TSRMLS_CC);

        /* Aynı sınıf girişiyle yeni bir nesne oluşturun. Bu bize sadece zend_object_value değerini
         * geri verecek, ancak yeni nesnenin gerçek iç yapısını geri vermeyecektir. */
        zend_object_value new_object_val = test_create_object_handler(Z_OBJCE_P(object) TSRMLS_CC);

        /* İç yapıyı elde etmek için, create_object işleyicisinden aldığımız 
         * işleyiciyi kullanarak onu nesne deposundan almamız gerekir. */
        test_object *new_object = zend_object_store_get_object_by_handle(
            new_object_val.handle TSRMLS_CC
        );

        /* Özellikleri kopyala ve __clone'u çağır */
        zend_objects_clone_members(
            &new_object->std, new_object_val,
            &old_object->std, Z_OBJ_HANDLE_P(object) TSRMLS_CC
        );

        /* İşte gerçek özel klonlama kodu geliyor */
        new_object->additional_property = old_object->additional_property;

        return new_object_val;
    }

    /* ... */
    test_object_handler.clone_obj = test_clone_handler;

Nesne deposuyla etkileşime girme
--------------------------------

Yukarıdaki kod örneklerinde, nesne deposuyla etkileşimde bulunmak için çeşitli işlevler gördünüz. İlki, nesneleri
depoya eklemek için kullanılan ``zend_objects_store_put`` idi. Ayrıca, nesneleri depodan geri almak için üç
fonksiyondan bahsedilmiştir:

``zend_object_store_get_object_by_handle()``, adından da anlaşılacağı gibi, tanıtıcısı verilen depodan bir nesne alır.
Bu işlev bir nesne işleyiciniz olduğunda, ancak ilişkili zval'a sahip olmadığınızda kullanılır (klon işleyicisindeki
gibi). Öte yandan çoğu durumda, bir zval kabul eden ve ondan kolu çıkaracak olan ``zend_object_store_get_object()``
işlevini kullanacaksınız.

Kullanılan üçüncü getter işlevi, ``zend_objects_get_address()``, yani ``zend_objectstore_get_object()`` ile aynı şeyi
yapar, ancak sonucu bir ``void*`` yerine ``zend_object*`` olarak döndürür. Bu işlev oldukça işe yaramaz gibi çünkü C
``void*```dan diğer işaretçi türlerine gizli atamalar sağlar.

Bu işlevlerin en önemlisi ``zend_object_store_get_object()``'dir. Çok kullanıyor olacaksınız. Hemen hemen tüm yöntemler
buna benzeyecek ::

    PHP_METHOD(Test, foo)
    {
        zval *object;
        test_object *intern;

        if (zend_parse_parameters_none() == FAILURE) {
            return;
        }

        object = getThis();
        intern = zend_object_store_get_object(object TSRMLS_CC);

        /* Burada bir şeyler yapın, dahili mülk iadesi gibi: */
        RETURN_LONG(intern->additional_property);
    }

Nesne deposu tarafından sağlanan başka fonksiyonlar da vardır; nesne refcountını yönetmek için, ancak bunlar nadiren
doğrudan kullanılır, bu yüzden burada ele alınmadı.