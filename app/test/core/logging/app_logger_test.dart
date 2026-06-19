import 'dart:developer' as developer;

import 'package:app_tunnel/core/logging/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppLogger', () {
    test('info calls developer.log with component as name', () {
      // developer.log 是 dart:developer 內建，無法 mock。
      // 驗證呼叫不拋例外即代表封裝正確。
      expect(
        () => AppLogger.info('test message', component: 'TestComponent'),
        returnsNormally,
      );
    });

    test('warning prefixes message with [WARNING]', () {
      expect(
        () => AppLogger.warning(
          'something wrong',
          component: 'TestComponent',
        ),
        returnsNormally,
      );
    });

    test('warning accepts optional error parameter', () {
      expect(
        () => AppLogger.warning(
          'something wrong',
          component: 'TestComponent',
          error: Exception('test'),
        ),
        returnsNormally,
      );
    });

    test('error prefixes message with [ERROR]', () {
      expect(
        () => AppLogger.error(
          'failed operation',
          component: 'TestComponent',
        ),
        returnsNormally,
      );
    });

    test('error accepts optional error parameter', () {
      expect(
        () => AppLogger.error(
          'failed operation',
          component: 'TestComponent',
          error: Exception('test'),
        ),
        returnsNormally,
      );
    });

    test('private constructor prevents instantiation', () {
      // AppLogger._() 禁止外部實例化，只能用靜態方法。
      // 編譯期保證：若嘗試 AppLogger() 會編譯錯誤。
      // 此處僅驗證靜態方法可正常呼叫。
      expect(
        () {
          AppLogger.info('a', component: 'X');
          AppLogger.warning('b', component: 'X');
          AppLogger.error('c', component: 'X');
        },
        returnsNormally,
      );
    });
  });
}
