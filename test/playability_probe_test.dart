import 'package:duanju_app/catalog_sort.dart';
import 'package:duanju_app/core_bridge.dart';
import 'package:duanju_app/home_screen.dart';
import 'package:duanju_app/local_store.dart';
import 'package:duanju_app/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

// resolve 一律失败的仓库：模拟源站取流链路全灭（如红果 2026-10-26 实测状态）。
class _DeadSourceRepository extends FixtureRepository {
  @override
  Future<PlaybackPlan> resolve(
    Drama drama,
    Episode episode, {
    int quality = 0,
    int route = 0,
  }) async => throw AppFailure('源站取流失败：合成死源');
}

// detail 一律失败的仓库：模拟源站详情链路失效。
class _DeadDetailRepository extends FixtureRepository {
  @override
  Future<DramaDetail> detail(Drama drama) async => throw AppFailure('源站详情链路失效');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('取流失败的剧封面标「无法播放」且可被筛选排除', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    addTearDown(store.dispose);

    final repository = _DeadSourceRepository();
    repository.cachedPages['hongguo'] = CatalogPage([FixtureRepository.free]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, store: store),
      ),
    );
    // 后台探测是异步链（detail→resolve→recordPlayability），推进若干帧与时间
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    // 1. 探测记录已写入且为 unplayable
    final record = store.playabilityOf(FixtureRepository.free.id);
    expect(record, isNotNull);
    expect(record!.status, PlayabilityStatus.unplayable);

    // 2. 「无法播放」标签已渲染（封面角标 + 列表摘要等多处）
    expect(find.text('无法播放'), findsWidgets);

    // 3. 筛选「免费完播」时该剧被排除，「无法播放」时保留
    final all = sortCatalog(
      [FixtureRepository.free],
      const CatalogView(playability: 'free'),
      playabilityOf: store.playabilityOf,
    );
    expect(all, isEmpty);
    final onlyDead = sortCatalog(
      [FixtureRepository.free],
      const CatalogView(playability: 'unplayable'),
      playabilityOf: store.playabilityOf,
    );
    expect(onlyDead, hasLength(1));

    // 4. 未探测（无记录）的剧在任何观看权限筛选下都隐藏，包括「免费完播」
    const unprobed = Drama(id: 'hongguo:999', source: 'hongguo', title: '未探测');
    for (final option in ['free', 'partial', 'locked', 'unplayable']) {
      final rows = sortCatalog(
        [unprobed],
        CatalogView(playability: option),
        playabilityOf: store.playabilityOf,
      );
      expect(rows, isEmpty, reason: '未探测剧不应出现在 $option 筛选结果');
    }
    // 集数完整度筛选同样隐藏未探测剧
    expect(
      sortCatalog(
        [unprobed],
        const CatalogView(completeness: 'complete'),
        playabilityOf: store.playabilityOf,
      ),
      isEmpty,
    );
  });

  testWidgets('detail 链路失效的剧同样标「无法播放」而非静默跳过', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    addTearDown(store.dispose);

    final repository = _DeadDetailRepository();
    repository.cachedPages['hongguo'] = CatalogPage([FixtureRepository.free]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, store: store),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    final record = store.playabilityOf(FixtureRepository.free.id);
    expect(record, isNotNull, reason: 'detail 失败必须落记录，不能静默跳过');
    expect(record!.status, PlayabilityStatus.unplayable);
  });

  // 回归守卫：探测在途时首页 generation 跳号（切后台/切页触发 _pauseCatalog）
  // 不得丢弃在途探测结果——记录是 store 级，与视图 generation 无关。
  testWidgets('探测在途时 generation 跳号仍落记录', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final store = LocalStore(await SharedPreferences.getInstance());
    addTearDown(store.dispose);

    final repository = _DeadSourceRepository();
    repository.cachedPages['hongguo'] = CatalogPage([FixtureRepository.free]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(repository: repository, store: store),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    // 模拟切后台再回前台：触发 _pauseCatalog → _generation++
    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 50));
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    final record = store.playabilityOf(FixtureRepository.free.id);
    expect(record, isNotNull, reason: 'generation 跳号不得丢弃在途探测结果');
    expect(record!.status, PlayabilityStatus.unplayable);
  });
}
