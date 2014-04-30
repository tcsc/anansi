import std.typecons;
import container;

final struct vecS {}
final struct listS {}

template Storage(Selector, ValueType) {
}

template Storage(Selector : vecS, ValueType) {
  alias StorageType = Array!ValueType;
  alias IndexType = size_t;

  auto push(ref StorageType store, ValueType value) {
    auto rval = store.insertBack(value);
    return tuple(rval, true);
  }

  void erase(ref StorageType store, IndexType index) {
    store.erase(index);
  }
}

template Storage(Selector : listS) {
  alias StorageType = List!ValueType;
  alias IndexType = List!(ValueType).Node*;

  auto push(ref StorageType, ValueType value) {
    auto rval = store.insertBack(value);
    return tuple(rval, true);
  }

  void erase(ref StorageType store, IndexType index) {
    store.erase(index);
  }
}
