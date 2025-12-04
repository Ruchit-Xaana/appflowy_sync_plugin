// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$documentsHash() => r'53a0f379284a6f5063d4a0304cb53d8fddbfaeff';

/// See also [Documents].
@ProviderFor(Documents)
final documentsProvider =
    AutoDisposeAsyncNotifierProvider<Documents, List<DocumentItem>>.internal(
      Documents.new,
      name: r'documentsProvider',
      debugGetCreateSourceHash:
          const bool.fromEnvironment('dart.vm.product')
              ? null
              : _$documentsHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$Documents = AutoDisposeAsyncNotifier<List<DocumentItem>>;
String _$editorStateWrapperHash() =>
    r'cd7f515dbff45928c1ce312cbb10188a1a116ffb';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$EditorStateWrapper
    extends BuildlessAutoDisposeAsyncNotifier<EditorState> {
  late final String docId;

  FutureOr<EditorState> build(String docId);
}

/// See also [EditorStateWrapper].
@ProviderFor(EditorStateWrapper)
const editorStateWrapperProvider = EditorStateWrapperFamily();

/// See also [EditorStateWrapper].
class EditorStateWrapperFamily extends Family<AsyncValue<EditorState>> {
  /// See also [EditorStateWrapper].
  const EditorStateWrapperFamily();

  /// See also [EditorStateWrapper].
  EditorStateWrapperProvider call(String docId) {
    return EditorStateWrapperProvider(docId);
  }

  @override
  EditorStateWrapperProvider getProviderOverride(
    covariant EditorStateWrapperProvider provider,
  ) {
    return call(provider.docId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'editorStateWrapperProvider';
}

/// See also [EditorStateWrapper].
class EditorStateWrapperProvider
    extends
        AutoDisposeAsyncNotifierProviderImpl<EditorStateWrapper, EditorState> {
  /// See also [EditorStateWrapper].
  EditorStateWrapperProvider(String docId)
    : this._internal(
        () => EditorStateWrapper()..docId = docId,
        from: editorStateWrapperProvider,
        name: r'editorStateWrapperProvider',
        debugGetCreateSourceHash:
            const bool.fromEnvironment('dart.vm.product')
                ? null
                : _$editorStateWrapperHash,
        dependencies: EditorStateWrapperFamily._dependencies,
        allTransitiveDependencies:
            EditorStateWrapperFamily._allTransitiveDependencies,
        docId: docId,
      );

  EditorStateWrapperProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.docId,
  }) : super.internal();

  final String docId;

  @override
  FutureOr<EditorState> runNotifierBuild(
    covariant EditorStateWrapper notifier,
  ) {
    return notifier.build(docId);
  }

  @override
  Override overrideWith(EditorStateWrapper Function() create) {
    return ProviderOverride(
      origin: this,
      override: EditorStateWrapperProvider._internal(
        () => create()..docId = docId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        docId: docId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<EditorStateWrapper, EditorState>
  createElement() {
    return _EditorStateWrapperProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is EditorStateWrapperProvider && other.docId == docId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, docId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin EditorStateWrapperRef
    on AutoDisposeAsyncNotifierProviderRef<EditorState> {
  /// The parameter `docId` of this provider.
  String get docId;
}

class _EditorStateWrapperProviderElement
    extends
        AutoDisposeAsyncNotifierProviderElement<EditorStateWrapper, EditorState>
    with EditorStateWrapperRef {
  _EditorStateWrapperProviderElement(super.provider);

  @override
  String get docId => (origin as EditorStateWrapperProvider).docId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
