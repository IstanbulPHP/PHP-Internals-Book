Sihirli arayüzler - Karşılaştırılabilir
=======================================

PHP'deki dahili arayüzler, kullanıcı eşdeğerlerine çok benzer. Tek önemli fark, iç arayüzlerin, arayüz uygulandığında
yürütülen bir işleyiciyi belirtme ihtimaline sahip olmasıdır. Bu özellik, ek kısıtlamalar uygulamak veya işleyicileri
değiştirmek gibi çeşitli amaçlar için kullanılabilir. Bunu, iç ``compare_objects`` işleyicisini kullanıcı alanına
gösteren "büyülü" ``Comparable`` arayüzünü uygulamak için kullanacağız.

Arayüzün kendisi aşağıdaki gibidir::

.. code-block:: php

    interface Comparable {
        static function compare($left, $right);
    }

Öncelikle bu yeni arayüzü ``MINIT``'a kaydedelim::

    zend_class_entry *comparable_ce;

    ZEND_BEGIN_ARG_INFO_EX(arginfo_comparable, 0, 0, 2)
        ZEND_ARG_INFO(0, obj1)
        ZEND_ARG_INFO(0, obj2)
    ZEND_END_ARG_INFO()

    const zend_function_entry comparable_functions[] = {
        ZEND_FENTRY(
            compare, NULL, arginfo_comparable, ZEND_ACC_PUBLIC|ZEND_ACC_ABSTRACT|ZEND_ACC_STATIC
        )
        PHP_FE_END
    };

    PHP_MINIT_FUNCTION(comparable)
    {
        zend_class_entry tmp_ce;
        INIT_CLASS_ENTRY(tmp_ce, "Comparable", comparable_functions);
        comparable_ce = zend_register_internal_interface(&tmp_ce TSRMLS_CC);

        return SUCCESS;
    }

Bu durumda ``PHP_ABSTRACT_ME`` kullanamayacağımıza dikkat edin, çünkü statik soyut yöntemleri desteklemiyor. Bunun
yerine, düşük seviyeli ``ZEND_FENTRY`` makrosunu kullanmalıyız.

Sonrasında ``interface_gets_implemented`` işleyicisini uyguluyoruz::

    static int implement_comparable(zend_class_entry *interface, zend_class_entry *ce TSRMLS_DC)
    {
        if (ce->create_object != NULL) {
            zend_error(E_ERROR, "Comparable interface can only be used on userland classes");
        }

        ce->create_object = comparable_create_object_override;

        return SUCCESS;
    }

    // in MINIT
    comparable_ce->interface_gets_implemented = implement_comparable;

Arayüz uygulandığında, ``implement_comparable`` işlevi çağrılacaktır. Bu fonksiyonda ``create_object`` işleyicisinin
sınıflarını geçersiz kılıyoruz. İşleri kolaylaştırmak için, arayüzün sadece ``create_object`` ``NULL`` iken
kullanılmasına izin veriyoruz ("normal" bir kullanıcı sınıfıdır). Eski ``create_object`` işleyicisini bir yerde
yedekleyerek bu çalışma üzerinde farklı denemeler de yapabiliriz.

Bizim ``create_object`` geçersiz kılmamızda, nesneyi her zamanki gibi oluştururuz ancak kendi işleyici yapımızı özel
bir ``compare_objects`` işleyici ile atarız::

    static zend_object_handlers comparable_handlers;

    static zend_object_value comparable_create_object_override(zend_class_entry *ce TSRMLS_DC)
    {
        zend_object *object;
        zend_object_value retval;

        retval = zend_objects_new(&object, ce TSRMLS_CC);
        object_properties_init(object, ce);

        retval.handlers = &comparable_handlers;

        return retval;
    }

    // In MINIT
    memcpy(&comparable_handlers, zend_get_std_object_handlers(), sizeof(zend_object_handlers));
    comparable_handlers.compare_objects = comparable_compare_objects;

Son olarak, özel karşılaştırma işleyicisini uygulamak zorundayız. Bu, ``zend_call_method_with_2_params`` makrosunu
kullanarak, ``zend_interfaces.h`` içinde tanımlanan ``compare`` yöntemini çağırır. Bunun sonucunda akıllara, yöntemin
hangi sınıfa çağrılması gerektiği sorusu gelir. Bu uygulama için ilk geçirilen nesneyi kullanacağız, ancak bu sadece
isteğe bağlı bir seçimdir. Bu, ``$left < $right`` için ``$left`` sınıfının kullanılacağı, ancak
``$left > $right`` için ``$right`` sınıfının kullanıldığı anlamına gelir. (Çünkü PHP ``>`` işlemini ``<``işlemine
dönüştürür.)

::

    #include "zend_interfaces.h"

    static int comparable_compare_objects(zval *obj1, zval *obj2 TSRMLS_DC)
    {
        zval *retval = NULL;
        int result;

        zend_call_method_with_2_params(NULL, Z_OBJCE_P(obj1), NULL, "compare", &retval, obj1, obj2);

        if (!retval || Z_TYPE_P(retval) == IS_NULL) {
            if (retval) {
                zval_ptr_dtor(&retval);
            }
            return zend_get_std_object_handlers()->compare_objects(obj1, obj2 TSRMLS_CC);
        }

        convert_to_long_ex(&retval);
        result = ZEND_NORMALIZE_BOOL(Z_LVAL_P(retval));
        zval_ptr_dtor(&retval);

        return result;
    }

Yukarıda kullanılan ``ZEND_NORMALIZE_BOOL`` makrosu, döndürülen tamsayıyı ``-1``, ``0`` ve ``1`` olarak normalleştirir.

Ve hepsi bu. Şimdi yeni arayüzü deneyebiliriz (örnek mantıklı gelmiyorsa üzgünüm):

.. code-block:: php

    class Point implements Comparable {
        protected $x, $y, $z;

        public function __construct($x, $y, $z) {
            $this->x = $x; $this->y = $y; $this->z = $z;
        }

        /* We assume a point is smaller/greater if all its components are smaller/greater */
        public static function compare($p1, $p2) {
            if ($p1->x == $p2->x && $p1->y == $p2->y && $p1->z == $p2->z) {
                return 0;
            }

            if ($p1->x < $p2->x && $p1->y < $p2->y && $p1->z < $p2->z) {
                return -1;
            }

            if ($p1->x > $p2->x && $p1->y > $p2->y && $p1->z > $p2->z) {
                return 1;
            }

            // not comparable
            return 1;
        }
    }

    $p1 = new Point(1, 1, 1);
    $p2 = new Point(2, 2, 2);
    $p3 = new Point(1, 0, 2);

    var_dump($p1 < $p2, $p1 > $p2, $p1 == $p2); // true, false, false

    var_dump($p1 == $p1); // true

    var_dump($p1 < $p3, $p1 > $p3, $p1 == $p3); // false, false, false

