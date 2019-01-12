Sınıflar ve nesneler
====================

Son yıllarda PHP, her geçen gün prosedürel bir dilden nesneye dayalı bir dile dönüşüyor. Temeller hala prosedürel
nitelikte olmasına rağmen (özellikle de standart kütüphanenin büyük bölümleri) günümüzdeki kütüphaneler sınıflar ve
nesne yönelimli geliştirilmektedir. Bu bölüm, PHP'nin nesne yönlü sisteminin oldukça karmaşık iç yapılarını
kapsamaktadır.

Contents:

.. toctree::
    :maxdepth: 2

    classes_objects/simple_classes.rst
    classes_objects/custom_object_storage.rst
    classes_objects/implementing_typed_arrays.rst
    classes_objects/object_handlers.rst
    classes_objects/iterators.rst
    classes_objects/serialization.rst
    classes_objects/magic_interfaces_comparable.rst
    classes_objects/internal_structures_and_implementation.rst

.. todo::
    * __construct is not always called
    * verify that ctors don't segfault or leak on manual call