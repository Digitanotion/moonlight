import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_update/in_app_update.dart' as play;
import 'package:moonlight/core/services/auto_update_service.dart';

/// Stand-in for Google Play: scripted answers, no Play install needed.
class FakePlay extends PlayUpdateApi {
  play.AppUpdateResult answer = play.AppUpdateResult.success;
  play.InstallStatus status = play.InstallStatus.unknown;
  play.UpdateAvailability availability = play.UpdateAvailability.updateAvailable;
  int starts = 0;
  int completes = 0;
  final events = StreamController<play.InstallProgress>.broadcast();

  @override
  Future<play.AppUpdateResult> startFlexibleUpdate() async {
    starts++;
    return answer;
  }

  @override
  Future<play.AppUpdateInfo> checkForUpdate() async => info();

  @override
  Future<void> completeFlexibleUpdate() async => completes++;

  @override
  Stream<play.InstallProgress> get installUpdates => events.stream;

  play.AppUpdateInfo info() => play.AppUpdateInfo(
    updateAvailability: availability,
    immediateUpdateAllowed: true,
    immediateAllowedPreconditions: null,
    flexibleUpdateAllowed: true,
    flexibleAllowedPreconditions: null,
    availableVersionCode: 62,
    installStatus: status,
    packageName: 'com.app.moonlightstream',
    clientVersionStalenessDays: 1,
    updatePriority: 0,
  );
}

void main() {
  late FakePlay fake;
  late AutoUpdateService svc;

  setUp(() {
    fake = FakePlay();
    svc = AutoUpdateService.forTesting(fake);
  });
  tearDown(() => svc.dispose());

  test('"No thanks" goes back to idle instead of a stuck download', () async {
    fake.answer = play.AppUpdateResult.userDeniedUpdate;

    expect(await svc.tryStart(fake.info()), isTrue);
    expect(svc.stage.value, AutoUpdateStage.idle);
    expect(svc.deniedThisSession, isTrue);

    // Doesn't pop Play's dialog again in the same session.
    await svc.tryStart(fake.info());
    expect(fake.starts, 1);
  });

  test('a Play failure flashes "failed" then returns to idle', () {
    fakeAsync((async) {
      fake.answer = play.AppUpdateResult.inAppUpdateFailed;
      svc.tryStart(fake.info());
      async.flushMicrotasks();
      expect(svc.stage.value, AutoUpdateStage.failed);
      async.elapse(const Duration(seconds: 4));
      expect(svc.stage.value, AutoUpdateStage.idle);
    });
  });

  test('accepted update downloads, then restarts by itself', () {
    fakeAsync((async) {
      svc.tryStart(fake.info());
      async.flushMicrotasks();
      expect(svc.stage.value, AutoUpdateStage.downloading);

      fake.events.add(
        const play.InstallProgress(
          status: play.InstallStatus.downloading,
          bytesDownloaded: 50,
          totalBytesToDownload: 100,
        ),
      );
      async.flushMicrotasks();
      expect(svc.progress.value, 0.5);

      fake.events.add(
        const play.InstallProgress(
          status: play.InstallStatus.downloaded,
          bytesDownloaded: 100,
          totalBytesToDownload: 100,
        ),
      );
      async.flushMicrotasks();
      expect(svc.stage.value, AutoUpdateStage.downloaded);

      async.elapse(const Duration(seconds: 6));
      expect(fake.completes, 1);
    });
  });

  test('watchdog finishes the update even if progress events never come', () {
    fakeAsync((async) {
      svc.tryStart(fake.info());
      async.flushMicrotasks();
      expect(svc.stage.value, AutoUpdateStage.downloading);

      // Play finished downloading but the listener event was lost.
      fake.status = play.InstallStatus.downloaded;
      async.elapse(const Duration(seconds: 21));
      expect(svc.stage.value, AutoUpdateStage.downloaded);

      async.elapse(const Duration(seconds: 6));
      expect(fake.completes, 1);
    });
  });

  test('watchdog clears the ring when Play has nothing in flight', () {
    fakeAsync((async) {
      svc.tryStart(fake.info());
      async.flushMicrotasks();
      fake.availability = play.UpdateAvailability.updateNotAvailable;
      fake.status = play.InstallStatus.unknown;
      async.elapse(const Duration(seconds: 21));
      expect(svc.stage.value, AutoUpdateStage.idle);
    });
  });

  test('an update downloaded in an earlier session installs on launch', () {
    fakeAsync((async) {
      fake.status = play.InstallStatus.downloaded;
      svc.tryStart(fake.info());
      async.flushMicrotasks();
      expect(svc.stage.value, AutoUpdateStage.downloaded);
      async.elapse(const Duration(seconds: 6));
      expect(fake.completes, 1);
      expect(fake.starts, 0); // no second dialog
    });
  });
}
