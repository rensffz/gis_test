// test/unit/providers/layers_notifier_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:gis_app/providers/app_providers.dart';
import 'package:gis_app/models/app_models.dart';
import '../../helpers/provider_container_helper.dart';
import '../../fixtures/test_fixtures.dart';
import '../../mocks/mock_repository.dart';

void main() {
  setUpAll(registerMockFallbacks);

  ProviderContainer makeContainerWithMock(MockAppRepository mock) {
    final container = ProviderContainer(
      overrides: [repoProvider.overrideWithValue(mock)],
    );
    addTearDown(container.dispose);
    return container;
  }

  final testLayers = [
    makeLayer(id: 'l1', name: 'Layer 1', isVisible: true),
    makeLayer(id: 'l2', name: 'Layer 2', isVisible: false),
    makeLayer(id: 'l3', name: 'Layer 3', type: LayerType.points, isVisible: true, tableId: 'tbl_1'),
  ];

  group('LayersNotifier', () {
    late MockAppRepository mock;

    setUp(() {
      mock = MockAppRepository();
      mock.stubFetchLayers('obj_1', testLayers);
      mock.stubUpdateLayerVisibility();
      mock.stubDeleteLayer();
      mock.stubAddLayer();
    });

    group('начальная загрузка', () {
      test('начинает с AsyncValue.loading', () {
        final container = makeContainerWithMock(mock);
        expect(container.read(layersProvider('obj_1')), isA<AsyncLoading>());
      });

      test('загружает слои после инициализации', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        final state = container.read(layersProvider('obj_1'));
        expect(state, isA<AsyncData<List<GisLayer>>>());
        expect(state.valueOrNull, hasLength(3));
      });

      test('разные objectId — независимые нотификаторы', () async {
        mock.stubFetchLayers('obj_2', [makeLayer(id: 'l99', name: 'Отдельный')]);
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await awaitNotifierData(container, layersProvider('obj_2'));
        expect(container.read(layersProvider('obj_1')).valueOrNull, hasLength(3));
        expect(container.read(layersProvider('obj_2')).valueOrNull, hasLength(1));
      });

      test('обрабатывает ошибку загрузки', () async {
        when(() => mock.fetchLayers('err_obj'))
            .thenThrow(Exception('Network error'));
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('err_obj'));
        expect(container.read(layersProvider('err_obj')), isA<AsyncError>());
      });
    });

    group('toggleVisibility', () {
      test('переключает видимость слоя', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        final notifier = container.read(layersProvider('obj_1').notifier);

        final l1Before = container.read(layersProvider('obj_1'))
            .valueOrNull!.firstWhere((l) => l.id == 'l1');
        expect(l1Before.isVisible, isTrue);

        await notifier.toggleVisibility('l1');
        final l1After = container.read(layersProvider('obj_1'))
            .valueOrNull!.firstWhere((l) => l.id == 'l1');
        expect(l1After.isVisible, isFalse);
      });

      test('вызывает repo.updateLayerVisibility', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await container.read(layersProvider('obj_1').notifier).toggleVisibility('l1');
        verify(() => mock.updateLayerVisibility('obj_1', 'l1', any())).called(1);
      });

      test('не меняет другие слои', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await container.read(layersProvider('obj_1').notifier).toggleVisibility('l1');
        final layers = container.read(layersProvider('obj_1')).valueOrNull!;
        final l2 = layers.firstWhere((l) => l.id == 'l2');
        expect(l2.isVisible, isFalse); // l2 не изменился
      });

      test('не делает ничего если state == null/loading', () async {
        final container = makeContainerWithMock(mock);
        // Не ждём загрузки — state ещё loading
        await container.read(layersProvider('obj_1').notifier).toggleVisibility('l1');
        verifyNever(() => mock.updateLayerVisibility(any(), any(), any()));
      });
    });

    group('deleteLayer', () {
      test('удаляет слой из state', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await container.read(layersProvider('obj_1').notifier).deleteLayer('l1');
        final layers = container.read(layersProvider('obj_1')).valueOrNull!;
        expect(layers.any((l) => l.id == 'l1'), isFalse);
        expect(layers.length, equals(2));
      });

      test('вызывает repo.deleteLayer', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await container.read(layersProvider('obj_1').notifier).deleteLayer('l2');
        verify(() => mock.deleteLayer('obj_1', 'l2')).called(1);
      });

      test('оставляет другие слои нетронутыми', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        await container.read(layersProvider('obj_1').notifier).deleteLayer('l1');
        final layers = container.read(layersProvider('obj_1')).valueOrNull!;
        expect(layers.any((l) => l.id == 'l2'), isTrue);
        expect(layers.any((l) => l.id == 'l3'), isTrue);
      });
    });

    group('addLayer', () {
      test('добавляет слой в конец списка', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        final newLayer = makeLayer(id: 'l_new', name: 'Новый слой');
        await container.read(layersProvider('obj_1').notifier).addLayer(newLayer);
        final layers = container.read(layersProvider('obj_1')).valueOrNull!;
        expect(layers.last.id, equals('l_new'));
        expect(layers.length, equals(4));
      });

      test('вызывает repo.addLayer', () async {
        final container = makeContainerWithMock(mock);
        await awaitNotifierData(container, layersProvider('obj_1'));
        final newLayer = makeLayer(id: 'l_call', name: 'CallTest');
        await container.read(layersProvider('obj_1').notifier).addLayer(newLayer);
        verify(() => mock.addLayer('obj_1', any())).called(1);
      });
    });
  });
}
